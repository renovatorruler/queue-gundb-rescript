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

@val external randomUUID: unit => string = "crypto.randomUUID"

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

let registerStore = async (name: name, email: email) => {
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
  let store = await storeRef->Gun.once()
  if (Js.Undefined.testAny(store)) {
    await storeRef->Gun.put({"createdAt": Js.Date.make()->Js.Date.toISOString})
  }
}

let parseStoreId = () => {
  let location = Webapi.Dom.window->Webapi.Dom.Window.location
  let path = location->Webapi.Dom.Location.pathname
  let parts = path->Js.String2.split("/")->Js.Array2.filter(part => part->Js.String2.length > 0)
  switch Belt.Array.get(parts, 0) {
  | Some(id) => id
  | None => {
      let id = randomUUID()
      let history = Webapi.Dom.window->Webapi.Dom.Window.history
      history->Webapi.Dom.History.replaceState(Obj.magic(Js.Obj.empty()), "", "/" ++ id)
      id
    }
  }
}

@react.component
let make = () => {
  let storeId = React.useMemo0(() => parseStoreId())
  React.useEffect1(() => {
    ensureStoreExists(storeId) |> ignore
    None
  }, [storeId])

  let (customerName, setCustomerName) = React.useState(() => "")
  let (queuePositionId, setQueuePositionId) = React.useState(() => "")

  let takeTicket = _ =>
    Js.Promise.then_(
      id => {
        setQueuePositionId(_ => id)
        Js.Promise.resolve()
      },
      enterQueue(customerName, storeId),
    )
    |> ignore

  <div className="container">
    <h1>{React.string("Take a Number")}</h1>
    <input
      value=customerName
      onChange={ev => setCustomerName(_ => ReactEvent.Form.target(ev)["value"])}
      placeholder="Your Name"
    />
    <div id="dispenser">
      <div
        id="ticket"
        draggable=true
        onDragEnd={_ => takeTicket()}
      >
        {React.string("Pull Ticket")}
      </div>
    </div>
    {switch queuePositionId {
    | "" => React.null
    | id => <p>{React.string("Queue Position ID: " ++ id)}</p>
    }}
  </div>
}
