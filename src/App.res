module Types = {
  type name = string
  type email = string

  let null = Js.Nullable.null
}
open Types

type algorithms = [#"SHA-256" | #PBKDF2]
type workOpt = {name: algorithms}
type gun
type sea

@module("gun/gun") external gun: unit => gun = "default"
@module("gun/sea") external sea: unit => sea = "default"

@send
external work: (
  sea,
  string,
  Js.Nullable.t<string>,
  Js.Nullable.t<unit => unit>,
  workOpt,
) => Js.Promise.t<string> = "work"

@send external get: (gun, string) => gun = "get"
@send external put: (gun, Js.t<'a>) => Js.Promise.t<unit> = "put"

let gun = gun()
let sea = sea()

let registerStore = async (name: name, email: email) => {
  let storeId = await sea->work(email, null, null, {name: #"SHA-256"})

  // Create a new store in GunDB
  let storeRef = gun->get(storeId)
  //   let objectToStore = Js.Obj.assign(Js.Obj.empty(), {name, email})
  await storeRef->put({"name": name, "email": email})
}

let _ = async () => {
  let storeId = await registerStore("My Store", "example@example.com")
  Js.log2("Store ID: ", storeId)
}
