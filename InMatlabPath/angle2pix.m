function pix = angle2pix(screen_width,screen_resolution_width, screen_distance, ang)
%pix = angle2pix(display,ang)
%
%converts visual angles in degrees to pixels.
%
%Inputs:
%display.dist (distance from screen (cm))
%display.width (width of screen (cm))
%display.resolution (number of pixels of display in horizontal direction)
%
%ang (visual angle)
%
%Warning: assumes isotropic (square) pixels

%Written 11/1/07 gmb zre

%Calculate pixel size
pixSize = screen_width/screen_resolution_width;   %cm/pix

sz = 2*screen_distance*tan(pi*ang/(2*180));  %cm

pix = round(sz/pixSize);   %pix


return

%test code

screen_dist = 60; %cm
screen_width = 44.5; %cm
screen_resolution = [1680,1050];
ang = 2.529;

angle2pix(screen_width, screen_resolution(1), screen_dist, ang)
