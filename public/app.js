const API_BASE = window.API_BASE || 'http://localhost:3000';

const flightsEl = document.getElementById('flights');
const seatMapEl = document.getElementById('seatMap');
const selectedFlightEl = document.getElementById('selectedFlight');
const cabinTabsEl = document.getElementById('cabinTabs');
const bookingResultEl = document.getElementById('bookingResult');
const managePanelEl = document.getElementById('managePanel');
const bookingSummaryEl = document.getElementById('bookingSummary');
const manageResultEl = document.getElementById('manageResult');
const manageSeatMapEl = document.getElementById('manageSeatMap');
const fromSelect = document.getElementById('from');
const toSelect = document.getElementById('to');

const dateInput = document.getElementById('date');

const airports = [
  { code: 'YYZ', name: 'Toronto Pearson' },
  { code: 'YVR', name: 'Vancouver Intl' },
  { code: 'YUL', name: 'Montreal Trudeau' },
  { code: 'LAX', name: 'Los Angeles Intl' },
  { code: 'JFK', name: 'New York JFK' }
];

const state = {
  flights: [],
  selectedFlight: null,
  selectedCabin: null,
  seats: [],
  selectedSeat: null,
  currentPnr: null,
  manageSeats: [],
  manageFlightId: null,
  manageCabin: null,
  manageSelectedSeat: null
};

const todayStr = new Date().toISOString().slice(0, 10);
const maxDate = new Date();
maxDate.setDate(maxDate.getDate() + 30);
const maxDateStr = maxDate.toISOString().slice(0, 10);
dateInput.value = todayStr;
dateInput.min = todayStr;
dateInput.max = maxDateStr;

function populateAirportSelect(selectEl, defaultCode) {
  selectEl.innerHTML = airports
    .map((a) => `<option value="${a.code}">${a.code} — ${a.name}</option>`)
    .join('');
  selectEl.value = defaultCode || airports[0].code;
}

populateAirportSelect(fromSelect, 'YYZ');
populateAirportSelect(toSelect, 'YVR');

document.getElementById('searchBtn').addEventListener('click', () => {
  searchFlights();
});

document.getElementById('bookBtn').addEventListener('click', () => {
  createBooking();
});

document.getElementById('lookupBtn').addEventListener('click', () => {
  lookupBooking();
});

document.getElementById('changeSeatBtn').addEventListener('click', () => {
  changeSeat();
});

document.getElementById('cancelBtn').addEventListener('click', () => {
  cancelBooking();
});

async function searchFlights() {
  flightsEl.textContent = 'Searching...';
  seatMapEl.innerHTML = '';
  selectedFlightEl.textContent = 'Select a flight to view seats.';
  state.selectedFlight = null;
  state.selectedSeat = null;
  bookingResultEl.textContent = '';

  const params = new URLSearchParams({
    from: document.getElementById('from').value.trim(),
    to: document.getElementById('to').value.trim(),
    date: document.getElementById('date').value
  });

  try {
    const res = await fetch(`${API_BASE}/api/flights?${params.toString()}`);
    if (!res.ok) throw new Error('Flight search failed');
    state.flights = await res.json();
    if (state.flights.length === 0) {
      flightsEl.textContent = 'No flights found for that day.';
      return;
    }
    flightsEl.innerHTML = state.flights
      .map(
        (flight) => `
      <div class="flight-card">
        <div class="flight-meta">
          <strong>${flight.flightNumber}</strong>
          <span>${flight.departureTs} → ${flight.arrivalTs}</span>
          <span>${flight.departureCode} → ${flight.arrivalCode}</span>
        </div>
        <div class="fare-buttons">
          <button data-flight="${flight.flightId}" data-cabin="ECONOMY" data-label="Economy">
            Economy ${flight.economyFare} (${flight.economyRemaining} left)
          </button>
          <button data-flight="${flight.flightId}" data-cabin="BUSINESS" data-label="Business">
            Business ${flight.businessFare} (${flight.businessRemaining} left)
          </button>
          <button data-flight="${flight.flightId}" data-cabin="FIRST" data-label="First">
            First ${flight.firstFare} (${flight.firstRemaining} left)
          </button>
        </div>
      </div>`
      )
      .join('');
    flightsEl.querySelectorAll('button').forEach((btn) => {
      btn.addEventListener('click', () => {
        selectFlight(Number(btn.dataset.flight), btn.dataset.cabin, btn.dataset.label);
      });
    });
  } catch (err) {
    flightsEl.textContent = err.message;
  }
}

function selectFlight(flightId, cabin, label) {
  state.selectedFlight = flightId;
  state.selectedCabin = cabin;
  selectedFlightEl.textContent = `Selected: ${flightId} (${label})`;
  renderCabinTabs();
  loadSeats();
}

function renderCabinTabs() {
  const cabins = ['ECONOMY', 'BUSINESS', 'FIRST'];
  cabinTabsEl.innerHTML = cabins
    .map(
      (cabin) => `<button class="${state.selectedCabin === cabin ? 'active' : ''}" data-cabin="${cabin}">
        ${cabin}
      </button>`
    )
    .join('');
  cabinTabsEl.querySelectorAll('button').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.selectedCabin = btn.dataset.cabin;
      state.selectedSeat = null;
      loadSeats();
    });
  });
}

async function loadSeats() {
  if (!state.selectedFlight || !state.selectedCabin) return;
  seatMapEl.textContent = 'Loading seats...';
  try {
    const params = new URLSearchParams({
      flightId: state.selectedFlight,
      cabin: state.selectedCabin
    });
    const res = await fetch(`${API_BASE}/api/seats?${params.toString()}`);
    if (!res.ok) throw new Error('Seat lookup failed');
    state.seats = await res.json();
    renderSeatMap();
  } catch (err) {
    seatMapEl.textContent = err.message;
  }
}

function renderSeatMap() {
  if (!state.seats.length) {
    seatMapEl.textContent = 'No seat data.';
    return;
  }

  const layout = getCabinLayout(state.selectedCabin);
  const rows = [...new Set(state.seats.map((s) => s.row))].sort((a, b) => a - b);
  const byRow = rows.map((row) => {
    const seatsInRow = state.seats.filter((s) => s.row === row);
    const groupsHtml = layout
      .map((group) => {
        const seatsHtml = group
          .map((label) => {
            const seat = seatsInRow.find((s) => s.seatNo === `${row}${label}`);
            if (!seat) {
              return '';
            }
            return `<div class="seat ${seat.status !== 'AVAILABLE' ? 'taken' : ''} ${seat.isExit ? 'exit' : ''} ${
              seat.isExtraLegroom ? 'extra' : ''
            } ${state.selectedSeat === seat.seatNo ? 'selected' : ''}" data-seat="${seat.seatNo}" data-status="${seat.status}">
              ${seat.seatNo}
            </div>`;
          })
          .join('');
        return `<div class="seat-group">${seatsHtml}</div>`;
      })
      .join('');

    return `<div class="seat-row">
      <div class="row-label">${row}</div>
      <div class="seat-groups">${groupsHtml}</div>
    </div>`;
  });

  seatMapEl.innerHTML = `<div class="seat-map-inner">${byRow.join('')}</div>`;

  seatMapEl.querySelectorAll('.seat').forEach((el) => {
    el.addEventListener('click', () => {
      if (el.dataset.status !== 'AVAILABLE') return;
      state.selectedSeat = el.dataset.seat;
      renderSeatMap();
    });
  });
}

function getCabinLayout(cabin) {
  if (cabin === 'FIRST') {
    return [['A'], ['D', 'G'], ['J']]; // 1-2-1 feel
  }
  if (cabin === 'BUSINESS') {
    return [['A', 'D'], ['G', 'J']]; // 2-2-2
  }
  // ECONOMY
  return [['A', 'B', 'C'], ['D', 'E', 'F'], ['G', 'H', 'J']]; // 3-3-3
}

async function loadManageSeats() {
  if (!state.manageFlightId || !state.manageCabin) {
    manageSeatMapEl.innerHTML = '';
    return;
  }
  manageSeatMapEl.textContent = 'Loading seats...';
  try {
    const params = new URLSearchParams({
      flightId: state.manageFlightId,
      cabin: state.manageCabin
    });
    const res = await fetch(`${API_BASE}/api/seats?${params.toString()}`);
    if (!res.ok) throw new Error('Seat lookup failed');
    state.manageSeats = await res.json();
    renderManageSeatMap();
  } catch (err) {
    manageSeatMapEl.textContent = err.message;
  }
}

function renderManageSeatMap() {
  if (!state.manageSeats.length) {
    manageSeatMapEl.textContent = 'No seat data.';
    return;
  }

  const layout = getCabinLayout(state.manageCabin);
  const rows = [...new Set(state.manageSeats.map((s) => s.row))].sort((a, b) => a - b);
  const byRow = rows.map((row) => {
    const seatsInRow = state.manageSeats.filter((s) => s.row === row);
    const groupsHtml = layout
      .map((group) => {
        const seatsHtml = group
          .map((label) => {
            const seat = seatsInRow.find((s) => s.seatNo === `${row}${label}`);
            if (!seat) return '';
            return `<div class="seat ${seat.status !== 'AVAILABLE' ? 'taken' : ''} ${seat.isExit ? 'exit' : ''} ${
              seat.isExtraLegroom ? 'extra' : ''
            } ${state.manageSelectedSeat === seat.seatNo ? 'selected' : ''}" data-seat="${seat.seatNo}" data-status="${seat.status}">
              ${seat.seatNo}
            </div>`;
          })
          .join('');
        return `<div class="seat-group">${seatsHtml}</div>`;
      })
      .join('');

    return `<div class="seat-row">
      <div class="row-label">${row}</div>
      <div class="seat-groups">${groupsHtml}</div>
    </div>`;
  });

  manageSeatMapEl.innerHTML = `<div class="seat-map-inner">${byRow.join('')}</div>`;

  manageSeatMapEl.querySelectorAll('.seat').forEach((el) => {
    el.addEventListener('click', () => {
      if (el.dataset.status !== 'AVAILABLE') return;
      state.manageSelectedSeat = el.dataset.seat;
      document.getElementById('newSeat').value = el.dataset.seat;
      renderManageSeatMap();
    });
  });
}

async function createBooking() {
  if (!state.selectedFlight || !state.selectedSeat) {
    bookingResultEl.textContent = 'Select a flight and seat first.';
    return;
  }
  const payload = {
    flightId: state.selectedFlight,
    cabin: state.selectedCabin,
    seatNo: state.selectedSeat,
    passengerName: document.getElementById('passengerName').value.trim(),
    passengerContact: document.getElementById('passengerContact').value.trim()
  };
  try {
    const res = await fetch(`${API_BASE}/api/bookings`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    if (!res.ok) {
      const errBody = await res.json();
      throw new Error(errBody.error || 'Booking failed');
    }
    const data = await res.json();
    bookingResultEl.textContent = `Issued. PNR ${data.pnr} / Ticket ${data.ticketNumber}`;
    state.currentPnr = data.pnr;
    document.getElementById('pnrLookup').value = data.pnr;
    loadSeats();
  } catch (err) {
    bookingResultEl.textContent = err.message;
  }
}

async function lookupBooking() {
  const pnr = document.getElementById('pnrLookup').value.trim();
  if (!pnr) return;
  manageResultEl.textContent = 'Looking up...';
  try {
    const res = await fetch(`${API_BASE}/api/bookings/${pnr}`);
    if (!res.ok) {
      const body = await res.json();
      throw new Error(body.error || 'Booking not found.');
    }
    const data = await res.json();
    state.currentPnr = data.pnr;
    managePanelEl.classList.remove('hidden');
    state.manageFlightId = data.flight.id;
    state.manageCabin = data.ticket.cabin;
    state.manageSelectedSeat = data.ticket.seatNo;
    bookingSummaryEl.innerHTML = `
      <p><strong>${data.flight.number}</strong> | ${data.flight.departure} → ${data.flight.arrival}</p>
      <p>${data.passenger.name} · Seat ${data.ticket.seatNo} (${data.ticket.cabin})</p>
      <p>Status: ${data.status}</p>`;
    manageResultEl.textContent = '';
    loadManageSeats();
  } catch (err) {
    managePanelEl.classList.add('hidden');
    manageResultEl.textContent = err.message;
  }
}

async function changeSeat() {
  if (!state.currentPnr) return;
  const seatNo = document.getElementById('newSeat').value.trim();
  if (!seatNo) return;
    manageResultEl.textContent = 'Changing seat...';
  try {
    const res = await fetch(`${API_BASE}/api/bookings/${state.currentPnr}/seat`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ seatNo })
    });
    if (!res.ok) {
      const body = await res.json();
      throw new Error(body.error || 'Seat change failed');
    }
    await res.json();
    manageResultEl.textContent = `Seat changed to ${seatNo}.`;
    lookupBooking();
  } catch (err) {
    manageResultEl.textContent = err.message;
  }
}

async function cancelBooking() {
  if (!state.currentPnr) return;
  if (!confirm('Cancel this booking?')) return;
  manageResultEl.textContent = 'Cancelling...';
  try {
    const res = await fetch(`${API_BASE}/api/bookings/${state.currentPnr}`, { method: 'DELETE' });
    if (!res.ok) {
      const body = await res.json();
      throw new Error(body.error || 'Cancel failed');
    }
    manageResultEl.textContent = 'Booking cancelled.';
    managePanelEl.classList.add('hidden');
    state.currentPnr = null;
  } catch (err) {
    manageResultEl.textContent = err.message;
  }
}
