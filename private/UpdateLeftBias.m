function UpdateLeftBias(TextHandler,~)
global TaskParameters;
LeftBiasHandle = GetGUIParamHandler('TaskParameters.GUI.LeftBias');
set(LeftBiasHandle, 'Value', str2num(TextHandler.String));
TaskParameters.GUI.LeftBias = str2num(TextHandler.String);
% Write the value to LeftBiasVal as well so it'd be read by the
% updateCustomDataFields function.
TaskParameters.GUI.LeftBiasVal = TextHandler.String;
end