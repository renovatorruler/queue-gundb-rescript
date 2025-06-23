@react.component
let make = () => {
  let path =
    Webapi.Dom.window
    ->Webapi.Dom.Window.location
    ->Webapi.Dom.Location.pathname

  let parts = Js.String.split("/", path)
  if Js.Array2.length(parts) >= 3 && Js.Array2.unsafe_get(parts, 1) == "store" {
    let storeId = Js.Array2.unsafe_get(parts, 2)
    <StorePage storeId />
  } else {
    <RootPage />
  }
}
