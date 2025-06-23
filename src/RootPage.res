open Api

@react.component
let make = () => {
  let (storeName, setStoreName) = React.useState(() => "")
  let (storeEmail, setStoreEmail) = React.useState(() => "")
  let (storeId, setStoreId) = React.useState(() => "")

  let register = _ =>
    Js.Promise.then_(
      id => {
        setStoreId(_ => id)
        Js.Promise.resolve()
      },
      registerStore(storeName, storeEmail),
    )
    |> ignore

  <div>
    <h1>{React.string("Queue App")}</h1>
    <div>
      <input
        value=storeName
        onChange={ev => setStoreName(_ => ReactEvent.Form.target(ev)["value"])}
        placeholder="Store Name"
      />
      <input
        value=storeEmail
        onChange={ev => setStoreEmail(_ => ReactEvent.Form.target(ev)["value"])}
        placeholder="Store Email"
      />
      <button onClick={_ => register()}>{React.string("Register Store")}</button>
    </div>
    {switch storeId {
    | "" => React.null
    | id =>
      <p>
        {React.string("Store created: ")}
        <a href={"/store/" ++ id}>{React.string(id)}</a>
      </p>
    }}
  </div>
}
