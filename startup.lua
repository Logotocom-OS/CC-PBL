local function crash(reason)
  term.setTextColor(colors.red)  

  write("Boot process failed: ")
  print(reason)
  
  print("Proceeding to run in CraftOS root!")
  print("For additional commands, run: pblhelp")
  print("")
  print("Press enter to continue to CraftOS")
  term.setTextColor(colors.white)
  io.read()
  error()
end

function main()
term.clear()
term.setCursorPos(1,1)
shell.setPath(shell.path()..":".."/tools/")
print("Partitioning Bootloader (PBL) is starting...")
print("Retrieving path...")
local path = shell.getRunningProgram()
print("Path is "..path)
if path ~= "startup" then
  print("Not running in root directory")
else
  print("Running in root environment")
  print("(At least that's what the bootloader sees,")
  print("This could very well be a chrooted environment.)")
end

print("Initializing mounting architecture")
local succ = shell.run("/pbl/mounter")

if not succ then crash("Failing to mount root.") end

print("Checking for disk drives..")
disks = fs.find("/disk*/")

print(#disks.." were found.")

print("Parsing partition configuration..")

if not fs.exists("/pbl/part.cfg") then
  crash("Partition table not found")
end

local fileHandle = fs.open("/pbl/part.cfg", "r")
local contents = fileHandle.readAll()
fileHandle.close()
filaHandle = nil

print("Unserailizing partition table...")
local ptbl = textutils.unserialize(contents)
contents = nil

if type(ptbl) ~= "table" then
  crash("Could not parse partition table.")
end

local bootables = 0

for k, v in pairs(ptbl) do
  if v.type == "os" then
    bootables = bootables + 1
  end
end

sleep(0.2)

print("")
print("Found "..#ptbl.." partitions; bootable: "..bootables)
print("")

if bootables == 0 then
  crash("No bootable partitions.")
end

sleep(0.2)

local oses = {}

for k,v in pairs(ptbl) do
  print("Found partition "..v.directory..", type "..v.type..": "..v.description)
  print("System is aware of partitions: "..tostring(v.aware)) 
  if v.type == "os" then
    table.insert(oses, v)
  end
end

local craftos = {
  ["aware"] = true,
  ["type"] = "os",
  ["directory"] = "/",
  ["description"] = "CraftOS",
}

local poweropts = {
  ["aware"] = false,
  ["type"] = "os",
  ["directory"] = "/",
  ["description"] = "Power options",
}

table.insert(oses, craftos)
table.insert(oses, poweropts)

print("")
print("Loading menu")
sleep(2)

term.clear()
term.setBackgroundColor(colors.white)
term.setTextColor(colors.purple)
term.setCursorPos(1,1)

local tX, tY = term.getSize()
local activeEntry = 1

--convenience functions
local function printCentered(text, yH)
  local tcp = (tX - string.len(text)) / 2
  term.setCursorPos(tcp, yH)
  print(text)
end

local function increaseEntry()
  if activeEntry ~= #oses then
    activeEntry = activeEntry + 1
  else
    activeEntry = 1
  end
end

local function decreaseEntry()
  if activeEntry ~= 1 then
    activeEntry = activeEntry - 1
  else
    activeEntry = #oses
  end
end

local function display()
  local yH = (tY - #oses) / 2
  
  printCentered("Please select an OS. (Use arrow keys)", yH - 3)
  
  for k, v in pairs(oses) do
    local currYH = yH + (k - 1)
    if k == activeEntry then
      term.setTextColor(colors.black)
      term.setBackgroundColor(colors.white)
      printCentered(" "..v.description.." ", currYH)
      term.setTextColor(colors.white)
      term.setBackgroundColor(colors.black)
    else
      printCentered(v.description, currYH)
    end
  end
  
  term.setCursorPos(1, tY - 1)
  print("Partition Bootloader (PBL) running on "..os.version())
end

local running = true

local function getInput()
  local event, key = os.pullEvent("key")
  if key == keys.down then
    increaseEntry()
  elseif key == keys.up then
    decreaseEntry()
  elseif key == keys.enter then
    running = false
  end
end

while running do
  term.clear()
  display()
  getInput()
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1,1)

local chosenOS = oses[activeEntry]
print("Chose OS "..chosenOS.description)
print("OS Root directoy: "..chosenOS.directory)
print("OS is aware of chroot: "..tostring(chosenOS.aware))
print("")

if chosenOS.description == "CraftOS" then
  print("Running CraftOS, aborting chroot")
  print("Booting directly into ROM")
  print("")
  print("Done.")
  sleep(0.2)
  error()  
end

if chosenOS.description == "Power options" then
  term.clear()
  term.setCursorPos(1,1)
  print("Running power options")
  print("Please select an option:")
  print("")
  print("1 Reboot")
  print("2 Shutdown")
  write("Choice: ")
  local choice = tostring(io.read())
  
  if choice ~= "1" then
    os.shutdown()
  else
    os.reboot()
  end
end

print("Performing chroot")

mounter.chroot(chosenOS.directory)
print("Done!")

if not chosenOS.aware then
  print("The chosen OS is not aware that it is being run in a sandboxed environment. Automatically mounting all disk drives...")
  for k, v in pairs(disks) do
    mounter.mount(v, v)
    print( "Mounted disk to \"" .. v .. "\" successfully" )
  end
  print("Mounting mounting tools for manual mounting after the fact.")
  mounter.mount("/tools/", "/tools")
end

print("Running startup...")
sleep(2)
shell.run("startup")
end

local ok, err = pcall(main)

if not ok then
  crash("Code Error: "..err)
end
