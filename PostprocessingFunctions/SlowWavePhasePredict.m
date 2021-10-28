function [vars, Graph, EEG] = SlowWavePhasePredict(EEG, vars, Graph)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

delta_filter = designfilt('bandpassiir', ...
    'PassbandFrequency1', .8, ... 
    'Passbandfrequency2', 3, ... 
    'StopbandFrequency1', .1,...
    'StopbandFrequency2', 9, ...
    'StopbandAttenuation1', 30, ...
    'StopbandAttenuation2', 30, ...
    'PassbandRipple', 1, ...
    'DesignMethod', 'butter', ...
    'SampleRate', EEG.fs);
[b_delta, a_delta] = tf(delta_filter);

if vars.SamplesInChunk > 0 %&& vars.UseSlowWaveStim
    if ~isfield(vars, 'PhasePredictor')
        load('10-26-2021 17-14results_Fpz_s02.mat', 'results');
        vars.PhasePredictor = resetState(results(1).net);
        vars.SlowWaveDelay = .000;
        vars.Angles = zeros(1000000, 1);
        vars.X = zeros(3, 1000000);
    end
    if ~vars.UseKalman
        if(vars.currentPosition - vars.SamplesInChunk)-1 <= 0
            sample =  EEG.Recording((vars.currentPosition - vars.SamplesInChunk):vars.currentPosition - 1, EEG.PrimaryChannel);
            sample = [0; sample];
        else
            sample =  EEG.Recording((vars.currentPosition - vars.SamplesInChunk)-1:vars.currentPosition - 1, EEG.PrimaryChannel);
        end
    else
        if(vars.currentPosition - vars.SamplesInChunk)-1 <= 0
            
            sample =  EEG.Kalman_Signal((vars.currentPosition - vars.SamplesInChunk):vars.currentPosition - 1, EEG.KalmanPrimary);
            sample = [0; sample];
        else
            sample =  EEG.Kalman_Signal((vars.currentPosition - vars.SamplesInChunk)-1:vars.currentPosition - 1, EEG.KalmanPrimary);
        end
    end
    [FiltSample, vars.z] = filter(vars.b, vars.a, sample(2:end), vars.z); 
    X = zeros(3, length(sample) - 1, 1, 1);
    X(1, :, 1, 1) = sample(2:end);
    X(2, :, 1, 1) = diff(sample);
    X(3, :, 1, 1) = FiltSample;
    [vars.PhasePredictor, Pred] = predictAndUpdateState(vars.PhasePredictor, {X});
    PredAngle = angle(Pred{1}(1, end) + sqrt(-1) * Pred{1}(2, end));
%     vars.X(:, vars.currentPosition - 1) = X(:, end, 1, 1);
%     vars.Angles(vars.currentPosition - 1) = PredAngle;
 %   fprintf('hi: %f\n', PredAngle);
    Mag = norm(Pred{1}(:, end)); 
    if (vars.currentPosition - vars.TriggerBuffer) > vars.LastStimPosition
        if Mag > EEG.Threshold
            if (PredAngle>=deg2rad(-60) && PredAngle<=deg2rad(-10))
                idx = (vars.currentPosition-EEG.fs*30-1):(vars.currentPosition-1);
                if mean(envelope(EEG.Recording(idx), length(idx), 'rms')) < 80 % check for mov artifacts
                    if mean(envelope(filter(b_delta, a_delta, EEG.Recording(idx)), length(idx), 'rms')) > 6 % check for delta
                        PsychPortAudio('Start', vars.audio_port, vars.repetitions, vars.ChunkTime + vars.SlowWaveDelay, 0);
                        %sound(Sound, fsSound)
                        vars.StimTimes(vars.StimCount) = round(vars.currentPosition + vars.SlowWaveDelay * EEG.fs);
                        vars.StimCount = vars.StimCount + 1;
                        vars.LastStimPosition = vars.currentPosition;
                    end
                end
            end
        end
    end
end
end