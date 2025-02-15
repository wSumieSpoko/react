document.addEventListener("DOMContentLoaded", function () {
  const { useState } = React;
  const { createRoot } = ReactDOM;

  function MyCalendar() {
    const [date, setDate] = useState(new Date());

    return (
      <div>
        <h3>Kalendarz</h3>
        <Calendar onChange={setDate} value={date} />
      </div>
    );
  }

  const rootElement = document.getElementById("calendar-root");
  if (rootElement) {
    const root = createRoot(rootElement);
    root.render(<MyCalendar />);
  } else {
    console.error("Nie znaleziono elementu #calendar-root");
  }
});
