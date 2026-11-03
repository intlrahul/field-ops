/// Known UI capabilities. Transport/domain storage keeps raw strings for forward compatibility.
nonisolated enum Capability: String, Sendable {
    case assetsRead = "assets.read"
    case assetsManage = "assets.manage"
    case inspectionsRead = "inspections.read"
    case inspectionsCreate = "inspections.create"
    case inspectionsAssign = "inspections.assign"
    case inspectionsPerform = "inspections.perform"
    case templatesManage = "templates.manage"
}
