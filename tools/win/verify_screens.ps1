Add-Type -AssemblyName System.Windows.Forms,System.Drawing,Microsoft.VisualBasic
Add-Type -Namespace W -Name U -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y); [DllImport("user32.dll")] public static extern void mouse_event(int f,int x,int y,int d,int e);'
function Click($x,$y){ [W.U]::SetCursorPos($x,$y); Start-Sleep -m 300; [W.U]::mouse_event(2,0,0,0,0); [W.U]::mouse_event(4,0,0,0,0) }
$exe="$env:LOCALAPPDATA\Programs\KasekriegRatOps\KasekriegRatOps.exe"
$o="$env:USERPROFILE\ratops"
function Shot($n){ $b=[System.Windows.Forms.SystemInformation]::VirtualScreen
 $bmp=New-Object System.Drawing.Bitmap $b.Width,$b.Height
 $g=[System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($b.Location,[System.Drawing.Point]::Empty,$b.Size)
 $bmp.Save("$o\$n.png"); $g.Dispose(); $bmp.Dispose() }
$p=Start-Process $exe -ArgumentList "--log-file `"$o\game-level.log`"" -PassThru
Start-Sleep 15
[Microsoft.VisualBasic.Interaction]::AppActivate($p.Id); Start-Sleep 1
Shot "menu"
$b=[System.Windows.Forms.SystemInformation]::VirtualScreen
Click ($b.Width/2) ($b.Height*0.553)   # New Game button
foreach($t in 1..4){ Start-Sleep 30; Shot "level-$t"; if($p.HasExited){ "exited" | Out-File "$o\exited.txt"; break } }
Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
"done" | Out-File "$o\level-done.txt"
