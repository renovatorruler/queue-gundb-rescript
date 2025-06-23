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

let registerStore = async (name: name, email: email) => {
  let storeId = await sea->Sea.asyncWork(email)

  let storeRef = gun->Gun.get(storesLabel)->Gun.get(storeId)
  await storeRef->Gun.put({"name": name, "email": email})
  storeId
}

let ensureStore = async storeId => {
  let storeRef = gun->Gun.get(storesLabel)->Gun.get(storeId)
  await storeRef->Gun.put({"id": storeId})
}

let enterQueue = async (customerName: name, storeId: storeId) => {
  let storeRef = gun->Gun.get("stores")->Gun.get(storeId)
  let _store = await storeRef->Gun.once()

  let queueRef = storeRef->Gun.get("queue")
  let _queue = await queueRef->Gun.once()

  let queuePosition = {
    customerName,
    position: 1,
    status: #waiting,
    timestamp: Js.Date.make()->Js.Date.toISOString,
  }

  await queueRef->Gun.set(queuePosition)

  let queuePositionId = await sea->Sea.asyncWork(`${customerName}:${queuePosition.timestamp}`)

  let queuePositionRef =
    gun
    ->Gun.get("queuePositions")
    ->Gun.getWithCallback(queuePositionId, _ => ())

  await queuePositionRef->Gun.put(queuePosition)
  queuePositionId
}

let unsetEverything = async storeId => {
  let storeRef = gun->Gun.get("stores")->Gun.get(storeId)
  await gun->Gun.unset(storeRef)
}

