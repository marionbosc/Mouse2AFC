function SerialConnect
global BpodSystem
if isempty(BpodSystem)
    error('Run bpod first before running this module');
end
list = seriallist;
[indx,tf] = listdlg('ListString',list,'SelectionMode','single');
if tf == 0
    disp('User cancelled choice - won''t connect')
    return
end
BpodSystem.PluginSerialPorts.OptoSerial = serial(list(indx),...
                                                'BaudRate',115200);
fopen(BpodSystem.PluginSerialPorts.OptoSerial);
end
