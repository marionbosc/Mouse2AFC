function UpdateLeftBiasVal(SliderHandler,~)
global TaskParameters;
LeftBiasValHandle = GetGUIParamHandler('TaskParameters.GUI.LeftBiasVal');
set(LeftBiasValHandle, 'String', num2str(SliderHandler.Value));
TaskParameters.GUI.LeftBiasVal = num2str(SliderHandler.Value);
% Write the value to LeftBias as well so it'd be read by the
% updateCustomDataFields function.
TaskParameters.GUI.LeftBias = SliderHandler.Value;
end
