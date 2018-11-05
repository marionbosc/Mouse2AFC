function [gabortex, propertiesMat] = GetGaborData(BpodCustomDataGrating, TaskParametersGUI)
% Dimension of the region where will draw the Gabor in pixels
gaborDimPix = BpodCustomDataGrating.windowRect(4) * TaskParametersGUI.gaborSizeFactor;
% Sigma of Gaussian
sigma = gaborDimPix / TaskParametersGUI.sigmaDivFactor; % Gamma and circle blurness around grating
% Obvious Parameters
freq = TaskParametersGUI.numCycles / gaborDimPix;
% Build a procedural gabor texture (Note: to get a "standard" Gabor patch
% we set a grey background offset, disable normalisation, and set a
% pre-contrast multiplier of 0.5.
% For full details see:
% https://groups.yahoo.com/neo/groups/psychtoolbox/conversations/topics/9174
backgroundOffset = [TaskParametersGUI.backgroundOffsetR
                    TaskParametersGUI.backgroundOffsetG
                    TaskParametersGUI.backgroundOffsetB
                    TaskParametersGUI.backgroundOffsetAlpha];
gabortex = CreateProceduralGabor(BpodCustomDataGrating.window,...
    gaborDimPix, gaborDimPix, [],backgroundOffset,...
    TaskParametersGUI.disableNorm, TaskParametersGUI.preContrastMultiplier);
% Randomise the phase of the Gabors and make a properties matrix.
propertiesMat = [TaskParametersGUI.phase, freq, sigma,...
                 TaskParametersGUI.contrast,...
                 TaskParametersGUI.aspectRatio, 0, 0, 0];
end