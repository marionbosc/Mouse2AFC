function homeCageServer()
global BpodSystem
t = tcpip('127.0.0.1', 30000, 'NetworkRole', 'server');
fopen(t);
%data = {};
%data = [data fread(t, t.BytesAvailable)];
while 1
    [line, count, msg] = fgetl(t);
    if msg
        if contains(msg, 'A timeout occurred before the Terminator was reached.')
            fwrite(t, 'pulsecheck');
            disp(t.Status);
            if strcmp(t.Status, 'closed')
                disp('Detected broken connection. Waiting for a new connection');
                fopen(t); % receive the next line
                disp('New connection received');
            else
                disp('Timeout reached. Trying to receive again.');
            end
            continue
        end
        disp("Error or warning")
        disp(msg);
    end
    fprintf("Received line: %s\n",line);
    LineSplitted = split(line);
    LS_Size = size(LineSplitted);
    disp("Split size:");
    disp(LS_Size);
    if all(LS_Size ~= [2 1])
        disp("Unexpected size received");
        continue;
    end
    AnimalName = LineSplitted(1);
    WaterAmount =  str2double(LineSplitted(2));
    ProtocolName = 'Mouse2AFC';
    SettingFileName = 'DefaultSettings';
    HomeCage = struct;
    HomeCage.WaterAmount = WaterAmount;
    HomeCage.MaxDuration = 60*30;
    HomeCage.ReportAnimalInsideFn = @()fwrite(t,'animal_inside');
    try
        runAnimalProtocol(AnimalName{:},ProtocolName,SettingFileName,...
                          HomeCage);
    catch ME
        fprintf('Caught an error while running protocol:\n');
        fprintf("%s\n", ME.message);
        fprintf('File: %s - Name: %s - Line: %d\n', ME.stack.file,...
            ME.stack.name, ME.stack.line);
        fprintf('Animal was: %s\n', AnimalName{:});
    end
    fwrite(t,'animal_done');
end
end