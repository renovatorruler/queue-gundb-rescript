open Util

let window_ = Webapi.Dom.window
let location = window_->Webapi.Dom.Window.location
let path = location->Webapi.Dom.Location.pathname

let segments = path->Js.String.split("/")->Belt.Array.keep(s => s != "")
let storeId =
  switch segments {
  | [id] => id
  | _ =>
    let id = Util.randomUUID()
    location->Webapi.Dom.Location.setPathname("/" ++ id)
    id
  }

let rootEl =
  Webapi.Dom.document
  ->Webapi.Dom.Document.getElementById("root")
  ->Belt.Option.getExn

let root = ReactDOM.Client.createRoot(rootEl)
root->ReactDOM.Client.Root.render(<StorePage storeId />)

