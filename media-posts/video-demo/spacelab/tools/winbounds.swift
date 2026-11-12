// Prints x,y,w,h (points) of the largest on-screen window whose owner name contains the argument.
import CoreGraphics
let needle = CommandLine.arguments[1].lowercased()
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
var best: CGRect? = nil
for w in list {
  guard let owner = (w[kCGWindowOwnerName as String] as? String)?.lowercased(), owner.contains(needle),
        let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
  let r = CGRect(x: b["X"]!, y: b["Y"]!, width: b["Width"]!, height: b["Height"]!)
  if best == nil || r.width * r.height > best!.width * best!.height { best = r }
}
if let r = best { print("\(Int(r.minX)),\(Int(r.minY)),\(Int(r.width)),\(Int(r.height))") } else { exit(1) }
