# hash_pin_socio.ps1 — generates the bcrypt hash for SOCIO_PIN_HASH from a PIN typed in a HIDDEN prompt.
# The PIN is never shown, never written to disk and never put on a command line; only the HASH goes to the clipboard.
# Rules: 8 or more digits (owner decision 2026-10-22). bcrypt cost 10 = what the API uses (bcrypt.hash(pin, 10)).
# Usage:  powershell -NoProfile -ExecutionPolicy Bypass -File hash_pin_socio.ps1
#         ... -SelfTest   (uses a dummy PIN, prints only length/prefix and whether it verifies; touches no clipboard)
# The hash contains "$" characters: paste it into the Railway variable field (not into a shell command line).
param([switch]$SelfTest)
$ErrorActionPreference = 'Stop'
$api = 'C:\Users\PC\barberpilot-api-duracion'   # any checkout that has node_modules with bcrypt
function Leer([string]$texto) {
  $s = Read-Host $texto -AsSecureString
  $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}
if ($SelfTest) { $p1 = '12345678'; $p2 = $p1 } else { $p1 = Leer 'Nuevo PIN de socio (8 o mas digitos)'; $p2 = Leer 'Repite el PIN' }
if ($p1 -ne $p2) { throw 'Los PIN no coinciden. No se hizo nada.' }
if ($p1 -notmatch '^[0-9]{8,}$') { throw 'El PIN debe tener 8 o mas digitos (solo numeros). No se hizo nada.' }
$env:NEW_PIN = $p1
try {
  Set-Location $api
  $js = "const b=require('bcrypt');const p=process.env.NEW_PIN;b.hash(p,10).then(async h=>{if(!(await b.compare(p,h))){process.exit(2)}process.stdout.write(h)})"
  $hash = & node -e $js
  if ($LASTEXITCODE -ne 0 -or -not $hash -or $hash.Length -ne 60 -or -not $hash.StartsWith('$2b$')) { throw 'No se pudo generar un hash valido. No se copio nada.' }
  if ($SelfTest) { Write-Host ('SELFTEST OK: hash de 60 caracteres, prefijo ' + $hash.Substring(0, 4) + ', verifica con el PIN de prueba. Nada copiado.') }
  else { Set-Clipboard -Value $hash; Write-Host 'Listo: el HASH (no el PIN) esta en el portapapeles. Pegalo en SOCIO_PIN_HASH y luego copia otra cosa para vaciarlo.' }
}
finally { Remove-Item Env:NEW_PIN -ErrorAction SilentlyContinue; $p1 = $null; $p2 = $null; $hash = $null }
