% RFControl - FlexRadio 6700 Serial CAT Control Example Script
% --------------------------------------------------
% 
% RF Control
% Module title: Control the Flex Radio 6500 and 6700 radios using 
%   flex6700CAT_v5.m class definition
% Description: Example script using serial port CAT commands and 
%   streaming audio.
% 
% Author: Dr. Gus K. Lott
% Company: YarCom Inc.
% Address: 8127 Mesa Dr., STE B206-318, Austin, TX 78759-8632
% Email: info@yarcom.com
% Website: http://www.yarcom.com
% 
% Revision:     1.0$    $Date: 2015/11/06
%
% Copyright 2015-present. Dr. Gus K. Lott, YarCom Inc., Austin, TX. 
%   All rights reserved.
% 
% This program is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
%     along with this program.  If not, see <http://www.gnu.org/licenses/>.
%
% Ref: (a) "FLEX-6000 SIGNATURE SERIES; SmartSDR CAT SOFTWARE USER'S
%   GUIDE, Version 1.6, 09/10/2015, SmartSDR CAT Version: 1.5.0" Refer
%   to this document for copyright and trademark notices. Also refer to
%   this document for details of each command.
%
% Required MATLAB toolboxes
%   None
% Required functions/classes
%   flex6700CAT_v5.m
% Required external software
%   SmartSDR CAT v1.5.1 (cat.exe)
%   DAX Control Panel v1.5.1.152 (dax.exe)
%   SmartSDR 1.5.1 - for settings below and to observe operations
%
% ******* Flex 6700 SET UP ********
% Two critical settings not controllable via CAT
% Turn ON DAX in the P/CW window
% Ensure TX LowCut and TX HighCut are set properly in PHNE window

%% Clear out environment
if ~isempty(timerfind)
    stop(timerfind) ;
    delete(timerfind) ;
end
delete(instrfindall)
delete(gcf)
close all
clear variables

%% set paths and file locations - ** YOU MUST SET YOUR PATHS **
addpath('C:\Users\user1\Documents\MATLAB\flexRadio\') ; % script files location
addpath('C:\Users\user1\Documents\MATLAB\iqTx\') ; % iq files to transmit
addpath('C:\Users\user1\Documents\MATLAB\audioTx\') ; % audio files to transmit
addpath('C:\Users\user1\Documents\MATLAB\iqRx\') ; % iq files received
addpath('C:\Users\user1\Documents\MATLAB\audioRx\') ; % audio files received

txDirName = 'C:\Users\user1\Documents\MATLAB\iqTx\' ; % TX waveform file location
txFileName = 'myWaveforms.mat' ; % TX waveform file - may contain multiple waveforms as separate variables
waveformFolder = fullfile(txDirName,txFileName) ;
whos(waveformFolder)
wfO = matfile(waveformFolder) ;
wNames = whos(wfO) ; % list of waveform variables in waveform file

%% Operating frequency lists with BW offsets - YOUR LICENSED FREQUENCIES
% YOU MUST ENTER YOUR FREQUENCY LIST FOR FREQUENCIES YOU ARE LICENSED
% TO USE - FREQUENCIES BELOW ARE JUST EXAMPLES
% freqListHz (n,1) = "center" frequency
% n = band selection, i = waveform bandwidth
% txFreq(n) = freqListHz(n,1)-freqListHz(n,i) - dial freq in DIGIU mode
% freqListHz = [7105000,1500,3000,4500,6000,12000,24000;...
%               14105000,1500,3000,4500,6000,12000,24000;...
%               21105000,1500,3000,4500,6000,12000,24000];

%% Establish serial port object, based on SmartSDRCAT running;
f1 = flex6700CAT_v5 ; % radio control object
f1.serialPort = 'COM4' ; % serial port in CAT for control - See SmartSDR CAT
f1.serialObject ; % serial port object

%% Initial radio configuration
f1.sliceNum = 0 ; % Use slice A=0 for RX and TX
f1.initialize ; % Initial setup to ensure repeatable configuration

%% Set DAX
f1.txDaxAudioNum = 1 ; % TX DAX Windows audio port
f1.rxDaxAudioNum = 1 ; % RX DAX Windows audio port
f1.getDaxAudioDevices ; % read Windows audio ports installed on computer

%% DAX and audio sampling rate information
f1.daxFs = 48000 ;
f1.nBits = 24 ;
f1.nChan = 1 ;

%% Waveform specific settings

% select TX slice 0 = Slice A
f1.in1 = 0 ; f1.setZZSW ; f1.getZZSW ; % slice A

% Set mode
mode = 'DIGU' ; % digital waveforms are normally in DIGU mode
f1.in1 = f1.mdValues{strcmpi(mode,f1.mdValues(:,2)),1} ; % finds numeric value for mode
f1.setZZMD ; % command mode

% Set power level
f1.in1 = 29 ; % power level ~ Watts 0-100
f1.setZZPC ; % command power level

% Set frequency index
txFreqIdx = 3 ; % n allows for selection from in freqListHz = 21105000 Hz
txBandwidthIdx = 2 ; % i sets waveform bandwidth selection = 1500 Hz

% Set listen-before-transmit (LBT) threshold
f1.chanOccupied = -107 ; % 1 uV received channel occupied threashold

% ******* SET UP ********
% ** Turn ON DAX in the P/CW window - not controllable via CAT
% ** Make sure Transmit bandwidth is properly set in the PHNE window
% 

for wIdx = 1:length(wNames) % wNames are the waveform variables in the waveform file
    % discover if TX file is audio or I/Q
    
    if ~isempty(regexpi(waveformFolder,'iqTx'))
        % True = waveform in iqTX folder and is in I/Q format
        iq = load(waveformFolder,wNames(wIdx).name) ;
        f1.txIQ = iq.(wNames(wIdx).name) ;
        f1.iq2Audio ;

        f1.in1 = freqListHz(txFreqIdx,1) - freqListHz(txFreqIdx,txBandwidthIdx) ; % set dial frequency
        f1.setZZFA ; % command dial frequency
        
        % Listen-Before-Transmit
        f1.getZZSM ; % read S-meter
        if f1.sm < f1.chanOccupied % listen before transmit
            f1.in1 = 1 ; % turn on
            f1.setZZTX ; % TX key transmitter
            f1.setAudio ; % send audio via DAX
            f1.in1 = 0 ; % turn off
            f1.setZZTX ; % RX unkey transmitter
        else
            disp('Channel Occupied')
        end
    else % False = waveform is in audioTx folder in single channel audio format 
    end
end

%}