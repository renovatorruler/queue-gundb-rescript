open Api

@react.component
let make = (~storeId: string) => {
let (customerName, _setCustomerName) = React.useState(() => "")
  let (ticketId, setTicketId) = React.useState(() => "")

  React.useEffect1(() => {
    ensureStore(storeId)->ignore
    None
  }, [storeId])

  let takeNumber = _ =>
    Js.Promise.then_(
      id => {
        setTicketId(_ => id)
        Js.Promise.resolve()
      },
      enterQueue(customerName == "" ? "Guest" : customerName, storeId),
    )
    |> ignore

  <div style={ReactDOM.Style.make(~padding="40px", ())}>
    <h2>{React.string("Store " ++ storeId)}</h2>
    <div
      style=
        ReactDOM.Style.make(
          ~width="200px",
          ~height="300px",
          ~borderRadius="10px",
          ~backgroundColor="#f0e0d6",
          ~boxShadow="inset 0 0 10px #aaa",
          ~display="flex",
          ~flexDirection="column",
          ~alignItems="center",
          ~justifyContent="center",
          (),
        )
    >
      <p>{React.string("Take a number")}</p>
      <button
        style=
          ReactDOM.Style.make(~marginTop="20px", ~padding="10px 20px", ())
        onClick={_ => takeNumber()}
      >{React.string("Pull Ticket")}</button>
    </div>
    {switch ticketId {
    | "" => React.null
    | id => <p>{React.string("Your ticket: " ++ id)}</p>
    }}
  </div>
}
