import Skitter.Component

component Skitter.Workflow.Source, in: __PRIVATE__, out: data do
  "Connection between a workflow and the external world"
  react(val, do: val ~> data)
end