// Moves the mouse pointer to x,y (global points) so it is not drawn over the recorded game.
import CoreGraphics
let a = CommandLine.arguments
CGWarpMouseCursorPosition(CGPoint(x: Double(a[1])!, y: Double(a[2])!))
