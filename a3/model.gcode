;Header start
G90 ; absolute mode for X/Y/Z
M82 ; absolute mode for E axis
G21 ; units in millimeters
M104 S200 ; set nozzle temperature
M140 S60 ; set bed temperature
G28 ; home print head
M109 S200 ; wait for nozzle temperature
M190 S60 ; wait for bed temperature
M106 S255 ; fan 100%
G1 Z5 F1440 ; lift nozzle before priming
G1 E5 F300 ; prepare nozzle by extruding filament
G92 E0 ; reset E axis 1
G92 E0 ; reset E axis 2
G92 E0 ; reset E axis 3
G1 E-2 F1800 ; retract filament
G0 Z5 F1440 ; move to safe Z height
G0 X10 Y10 F1440 ; safe starting position
G92 E0
;Layer 1 start
G0 X30.000 Y50.000 Z0.200 F1440
G1 X60.000 Y25.000 Z0.200 E1.55862 F900
G1 X90.000 Y50.000 Z0.200 E3.11724 F900
G1 X80.000 Y100.000 Z0.200 E5.15237 F900
G1 X40.000 Y100.000 Z0.200 E6.74885 F900
G1 X30.000 Y50.000 Z0.200 E8.78398 F900
;Footer start
M107 ; turn off fan
M104 S0 ; turn off nozzle heating
M140 S0 ; turn off bed heating
G1 E-2 F1800 ; retract filament
G0 Z330 F1440 ; move print head all the way up
G0 X0 Y350 F1440 ; move head left and bed forward
