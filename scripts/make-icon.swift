import AppKit
let dir=URL(fileURLWithPath:CommandLine.arguments[1])
try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
for size in [16,32,128,256,512] {
 for scale in [1,2] {
  let n=size*scale, s=CGFloat(n)
  let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:n,pixelsHigh:n,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
  NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
  NSColor(calibratedRed:0.10,green:0.17,blue:0.29,alpha:1).setFill()
  NSBezierPath(roundedRect:NSRect(x:s*0.07,y:s*0.07,width:s*0.86,height:s*0.86),xRadius:s*0.18,yRadius:s*0.18).fill()
  let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:s*0.5,weight:.semibold),.foregroundColor:NSColor.white]
  let label="12" as NSString; let bounds=label.size(withAttributes:attrs)
  label.draw(at:NSPoint(x:(s-bounds.width)/2,y:(s-bounds.height)/2+s*0.05),withAttributes:attrs)
  NSColor(calibratedRed:0.35,green:0.76,blue:0.96,alpha:1).setFill()
  NSBezierPath(roundedRect:NSRect(x:s*0.31,y:s*0.22,width:s*0.38,height:s*0.045),xRadius:s*0.022,yRadius:s*0.022).fill()
  NSGraphicsContext.restoreGraphicsState()
  let suffix=scale==2 ? "@2x":""
  try rep.representation(using:.png,properties:[:])!.write(to:dir.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
 }
}
