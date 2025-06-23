let rootEl =
  Webapi.Dom.document
  ->Webapi.Dom.Document.getElementById("root")
  ->Belt.Option.getExn

let root = ReactDOM.Client.createRoot(rootEl)
root->ReactDOM.Client.Root.render(<App />)

