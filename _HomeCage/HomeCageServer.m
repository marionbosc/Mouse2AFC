function HomeCageServer()
global BpodSystem
t = tcpip('127.0.0.1', 30000, 'NetworkRole', 'server');
fopen(t);
disp(t);

FinishMsg = 'Reason Not yet set';
function setFinishMsg(FinishMessage)
    FinishMsg = FinishMessage;
end

while 1
    [line, count, msg] = fgetl(t);
    if msg % An error message
        if contains(msg, 'A timeout occurred before the Terminator was reached.')
            fwrite(t, ['pulsecheck' char(13) newline]);
            disp(t.Status);
            if strcmp(t.Status, 'closed')
                disp('Detected broken connection. Waiting for a new connection');
                fopen(t); % receive new connection
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
    line = regexprep(line,'\r','');
    LineSplitted = split(line, " ");
    LS_Size = size(LineSplitted);
    disp("Split size:");
    disp(LS_Size);
    disp("Splitted:");
    disp(LineSplitted)
    if all(LS_Size ~= [5 1])
        disp("Unexpected size received");
        continue;
    end
    AnimalName = LineSplitted{1};
    ProtocolName = LineSplitted{2};
    SettingFileName = LineSplitted{3};
    MaxRewardAmount = str2double(LineSplitted{4});
    MaxDuration = str2double(LineSplitted{5});
    HomeCage = struct;
    HomeCage.MaxRewardAmount = MaxRewardAmount;
    HomeCage.MaxDuration = MaxDuration;
    FinishMsg = 'Reason Not yet set';
    HomeCage.setFinishMsg = @setFinishMsg;
    HomeCage.ReportAnimalInsideFn = @()fwrite(...
                                    t,['animal_inside' char(13) newline ]);
    disp("HomeCage struct:");
    disp(HomeCage);
    try
        runAnimalProtocol(AnimalName,ProtocolName,SettingFileName,...
                          HomeCage);
    catch ME
        fprintf('Caught an error while running protocol:\n');
        fprintf("%s\n", getReport(ME));% ME.message);
        %fprintf('File: %s - Name: %s - Line: %d\n', ME.stack.file,...
        %    ME.stack.name, ME.stack.line);
        fprintf('Running animal is: %s\n', AnimalName);
        FinishMsg = strcat(FinishMsg, ' - ', sprintf('Error occurred'));
    end
    DoneReply = sprintf('animal_done - Name: %s - Reason: %s%s%s',...
        AnimalName, FinishMsg, char(13), newline);
    fwrite(t, DoneReply);
end
end
