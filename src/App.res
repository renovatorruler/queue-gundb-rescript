module Constants = {
  let gunUrl = ["https://gun-manhattan.herokuapp.com/gun", "http://cashtokens.paper.cash:8765/gun"]
  let storesLabel = "stores"
}
module Types = {
  type name = string
  type email = string
  type storeId = string
  type timestamp = string
  type propertyLabel = string
  type status = [#waiting]

  let null = Js.Nullable.null
}
open Types
open Constants

module Sea = {
  type sea
  type algorithm = [#"SHA-256" | #PBKDF2]
  type workOpt = {name: algorithm}
  @module("gun/sea.js") external sea: sea = "default"
  @send
  external work: (
    sea,
    string,
    Js.Nullable.t<string>,
    Js.Nullable.t<unit => unit>,
    workOpt,
  ) => Js.Promise.t<storeId> = "work"

  let asyncWork = async (sea, string) => {
    await work(sea, string, null, null, {name: #"SHA-256"})
  }
}

module Gun = {
  type gun
  type gunOpts = {peers: array<string>}
  type storageObj<'t> = 't
  type callback<'a> = 'a => unit
  @module("gun") external gun: gunOpts => gun = "default"
  @module("gun/lib/unset.js") external unset_: gun = "default"
  let _ = unset_
  @send external get: (gun, propertyLabel) => gun = "get"
  @send external getWithCallback: (gun, propertyLabel, callback<'a>) => gun = "get"
  @send external put: (gun, storageObj<'a>) => promise<unit> = "put"
  @send external putWithCallback: (gun, storageObj<'a>, callback<'a>) => Js.Promise.t<unit> = "put"
  @send external once: (gun, unit) => promise<'a> = "once"
  @send external on: (gun, callback<'a>) => promise<'a> = "on"
  @send external unset: (gun, gun) => promise<unit> = "unset"
  @send external set: (gun, storageObj<'a>) => promise<unit> = "set"
}

type queuePosition = {
  customerName: name,
  position: int,
  status: status,
  timestamp: timestamp,
}
type queue = array<queuePosition>
type store = {queue: queue}

let gun = Gun.gun({peers: gunUrl})
let sea = Sea.sea

let registerStoreAsync = async (name: name, email: email) => {
  let storeId = await sea->Sea.asyncWork(email)

  // Create a new store in GunDB
  let storeRef = gun->Gun.get(storesLabel)->Gun.get(storeId)
  await storeRef->Gun.put({"name": name, "email": email})
  storeId
}

let enterQueue = async (customerName: name, storeId: storeId) => {
  let storeRef = gun->Gun.get("stores")->Gun.get(storeId)
  let store = await storeRef->Gun.once()
  Js.log2("store", store)

  let queueRef = storeRef->Gun.get("queue")
  let queue = await queueRef->Gun.once()
  Js.log2("queue", queue)

  // Create a new queue position object for the user
  let queuePosition = {
    customerName,
    position: 1,
    status: #waiting,
    timestamp: Js.Date.make()->Js.Date.toISOString,
  }
  Js.log2("queuePosition", queuePosition)

  // Add the queue position object to the store's queue array
  await queueRef->Gun.set(queuePosition)
  let queueArr = queueRef->Gun.once()
  Js.log2("queueArr", queueArr)

  // Generate a unique queue position ID using the user's name and timestamp
  let queuePositionId = await sea->Sea.asyncWork(`${customerName}:${queuePosition.timestamp}`)

  // Create a new queue position object in GunDB with the generated ID as the reference
  let queuePositionRef =
    gun
    ->Gun.get("queuePositions")
    ->Gun.getWithCallback(queuePositionId, x => Js.log2("queuePositionId", x))

  let queueD = await queuePositionRef->Gun.put(queuePosition)
  Js.log2("queueD", queueD)

  // Return the queue Position ID
  queuePositionId
}

let unsetEverything = async storeId => {
  let storeRef = gun->Gun.get("stores")->Gun.get(storeId)
  await gun->Gun.unset(storeRef)
}

let ensureStoreExists = async storeId => {
  let storeRef = gun->Gun.get(storesLabel)->Gun.get(storeId)
  await storeRef->Gun.put({"id": storeId})
}

module RegisterStore = {
  @react.component
  let make = () => {
  let (storeName, setStoreName) = React.useState(() => "")
  let (storeEmail, setStoreEmail) = React.useState(() => "")
  let (storeId, setStoreId) = React.useState(() => "")
  let (customerName, setCustomerName) = React.useState(() => "")
  let (queuePositionId, setQueuePositionId) = React.useState(() => "")

  let register = _ =>
    Js.Promise.then_(
      id => {
        setStoreId(_ => id)
        Js.Promise.resolve()
      },
      registerStoreAsync(storeName, storeEmail),
    )
    |> ignore

  let enter = _ =>
    Js.Promise.then_(
      id => {
        setQueuePositionId(_ => id)
        Js.Promise.resolve()
      },
      enterQueue(customerName, storeId),
    )
    |> ignore

  <div>
    <h1>{React.string("Queue App")}</h1>
    <div>
      <input
        value=storeName
        onChange={ev =>
          setStoreName(_ => ReactEvent.Form.target(ev)["value"])
        }
        placeholder="Store Name"
      />
      <input
        value=storeEmail
        onChange={ev =>
          setStoreEmail(_ => ReactEvent.Form.target(ev)["value"])
        }
        placeholder="Store Email"
      />
      <button onClick={_ => register()}>{React.string("Register Store")}</button>
    </div>
    {switch storeId {
    | "" => React.null
    | id => <p>{React.string("Store ID: " ++ id)}</p>
    }}
    <div>
      <input
        value=customerName
        onChange={ev =>
          setCustomerName(_ => ReactEvent.Form.target(ev)["value"])
        }
        placeholder="Your Name"
      />
      <button onClick={_ => enter()}>{React.string("Enter Queue")}</button>
    </div>
    {switch queuePositionId {
    | "" => React.null
    | id => <p>{React.string("Queue Position ID: " ++ id)}</p>
    }}
  </div>
  }
}

module CustomerPage = {
  @react.component
  let make = (~storeId: string) => {
    let (ticketId, setTicketId) = React.useState(() => "")
    React.useEffect0(() => {
      ensureStoreExists(storeId) |> ignore
      None
    })

    let take = _ =>
      Js.Promise.then_(
        id => {
          setTicketId(_ => id)
          Js.Promise.resolve()
        },
        enterQueue("Guest", storeId),
      )
      |> ignore

    <div>
      <h1>{React.string("Take a number")}</h1>
      <div className="dispenser">
        <div
          className="ticket"
          draggable=true
          onDragStart={_ => take()}
          onClick={_ => take()}
        >
          {React.string("Pull Ticket")}
        </div>
      </div>
      {switch ticketId {
      | "" => React.null
      | id => <p>{React.string("Ticket ID: " ++ id)}</p>
      }}
    </div>
  }
}

let getStoreIdFromPath = () => {
  let location = Webapi.Dom.window->Webapi.Dom.Window.location
  let pathname = location->Webapi.Dom.Location.pathname
  let trimmed = Js.String2.sliceToEnd(pathname, ~from=1)
  if trimmed == "" {
    None
  } else {
    Some(trimmed)
  }
}

@react.component
let make = () => {
  switch getStoreIdFromPath() {
  | None => <RegisterStore />
  | Some(id) => <CustomerPage storeId=id />
  }
}
