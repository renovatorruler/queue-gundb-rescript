open App
open Util

let ensureStoreExists = async storeId => {
  let storeRef = App.gun->App.Gun.get(App.Constants.storesLabel)->App.Gun.get(storeId)
  // Put a placeholder to ensure the store exists
  await storeRef->App.Gun.put({"created": Js.Date.make()->Js.Date.toISOString})
}

@react.component
let make = (~storeId: string) => {
  let (ticketId, setTicketId) = React.useState(() => "")

  React.useEffect0(() => {
    ensureStoreExists(storeId)->ignore
    None
  });

  let takeNumber = _ =>
    Js.Promise.then_(
      id => {
        setTicketId(_ => id)
        Js.Promise.resolve()
      },
      App.enterQueue("Customer", storeId),
    )
    |> ignore

  <div className="store-page">
    <h2>{React.string("Take a Number")}</h2>
    <div className="dispenser" draggable=true onDragEnd={_ => takeNumber()}>
      <div className="ticket" />
    </div>
    {switch ticketId {
    | "" => React.null
    | id => <p className="ticket-display">{React.string("Ticket ID: " ++ id)}</p>
    }}
  </div>
}

