classdef flex6700CAT_v5 < handle

% RFControl - FlexRadio 6700 Serial CAT Control
% --------------------------------------------------
% 
% RF Control
% Module title: Control the Flex Radio 6500 and 6700 radios using the CAT
%       port
% Description: Remote control of the Flex Radio 6700, including sending and
%   receiving audio, computer control of radio settings, and other
%   functions - using serial port CAT commands and streaming audio.
% 
% Author: Dr. Gus K. Lott
% Company: YarCom Inc.
% Address: 8127 Mesa Dr., STE B206-318, Austin, TX 78759-8632
% Email: info@yarcom.com
% Website: http://www.yarcom.com
% 
% Revision:     5.0$    $Date: 2015/11/05
%               4.0$    $Date: 2015/05/06
%               3.0$    $Date: 2015/04/10
%               2.1$    $Date: 2014/09/12
%               2.0$    $Date: 2014/05/01
%               1.0$    $Date: 2013/12/14
% 
% Revision history:
% 5.0. Updated to reflect SmartSDR CAT 1.5.1, add defaults and value
%   checking
% 4.0. Updated to reflect SmartSDR CAT 1.4.11.
%   Consolidated ZZ and Kenwood properties and methods, 
%   unified response parsing, added audio commands. 
% 3.0.Updated to reflect SmartSDR CAT 1.4.3.
% 2.1. Expanded and updated CAT commands
% 2.0. Added CAT commands, initial response handler
% 1.0. Initial version - serial CAT commands
% 
% Copyright 2013-present. Dr. Gus K. Lott, YarCom Inc., Austin, TX. 
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
%   None
% Required external software
%   SmartSDR CAT v1.5.1 (cat.exe)
%   DAX Control Panel v1.5.1.152 (dax.exe)
%   SmartSDR 1.5.1 - for critical settings and to observe operations
%
% ******* Flex 6700 SET UP ********
% Two critical settings not controllable via CAT
% Turn ON DAX in the P/CW window
% Ensure TX LowCut and TX HighCut are set properly in PHNE window
%
% ******* Known Command Issues ********
% ZZGT and GT get and set do not function
% KY does not function
% Normally, you will only have one slice A = 0 in operation. You get errors
%   if you try to command Slice B = 1 if there is no second slice open.

    properties % common site properties
        % Station info
        rxName ; % string Rx site name
        rxLat ; % double Rx Site Longitude dd.ddddd +N  -S
        rxLon ; % double Rx Site Longitude ddd.ddddd +E -W
        rxGrid ; % string Rx Maidenhead grid square 
        txName ; % string Tx site name
        txLat ; % double Tx Site Longitude dd.ddddd +N  -S
        txLon ; % double Tx Site Longitude ddd.ddddd +E -W
        txGrid ; % string Tx Maidenhead grid square
        txTimeLimit = 60 ; % double Maximum transmit time seconds
        chanOccupied = -107 ; % double dBm channel occupied threshold 
    end

    properties % CAT properties
        %% CAT serial communications
        serialPort ; % string serial COM port 'COM4'
        serialObj ; % serial port object created
        writeData ; % string to send to serial port
        readData ; % string read from serial input buffer
        readError ; % double 0 = no error; 1 = error
        readText ;  % string readData if no matching command value
        
        sliceNum = 0 ; % double [0-7] for slice receivers A,B,...,H 
        defaultFreqHz = 7200000 ; % double default frequency setting Hz
        
        %% CAT command values
        in1 ; % input 1 for set command
        in2 ; % input 2 for set command
        
        ag ; % double slice A audio gain 0-100
        ai ; % double auto info mode 0 auto information disabled, P1 = 1 auto information enabled
        de ; % double diversity mode 6700 only 0 = off, 1 = on
        fa ; % double slice A freq Hz
        fb ; % double slice B freq Hz
        fi ; % double slice A dsp filter 0 thru 7 
        fj ; % double slice B dsp filter 0 thru 7
        fiValues = [00,4000,20000,3000,5000,NaN,NaN,NaN,3000;...
                   01,3300,16000,1500,3000,16000,NaN,NaN,1500;...
                   02,2900,14000,1000,2000,NaN,NaN,NaN,1000;...
                   03,2700,12000,0800,1500,NaN,11000,1800,0500;...
                   04,2400,10000,0400,1000,NaN,NaN,NaN,0400;...
                   05,2100,08000,0250,0600,NaN,NaN,NaN,0350;...
                   06,1800,06000,0100,0300,NaN,NaN,NaN,0300;...
                   07,1600,05600,0050,0100,NaN,NaN,NaN,0250] ;
        fiModes = {'USB/LSB','S/AM','CW','DIGL/DIGU','FM/DFM','FMN','FDV','RTTY'} ;
        fr ; % double transmit flag 0 1
        ft ; % double transmit flag
        gt ; % double agc mode
        gtValues = 0:4 ; % radio index
        gtLables = {'Off','','Slow','Med','Fast'} ; % string
        id ; % double
        idLabels = {904,'Flex-6700';...
                    905,'Flex-6500';...
                    906,'Flex-6700R';...
                    907,'Flex-6300'} ;
        ifk = struct(...
            'fa',[],... % VFO A Hz 11 digits
            'fss',[],... % see fssLabels
            'itf',0,... % not implemented RIT/XIT freq Hz (000000)
            'rit',[],... % 0 = off, 1 = on
            'xit',[],... % 0 = off, 1 = on
            'cbn1',0,... % not used = 00
            'cbn2',0,... % not used = 00
            'mox',[],... % MOX 0 = off, 1 = on
            'mode',[],... % see ModeLabelsK
            'fr',[],... % see case FR
            'scan',0,... % not used = 0
            'ft',[],... % see case FT
            'ctcss',0,... % not used = 0
            'tone',0,... % not used = 00
            'shift',0) ; % not used = 0
        ks ; % CW keying speed 005-050
        ky ; % [P1,P2...P2] CWX
        le ; % double slice B audio gain 0-100
        md ; % double slice A dsp mode 1st column mdValues
        me ; % double slice B dsp mode 1st column mdValues
        mdValues =  {00,'LSB';...
                     01,'USB';...
                     03,'CWL';...
                     04,'CWU';...
                     05,'FM';...
                     06,'AM';...
                     07,'DIGU';...
                     09,'DIGL';...
                     10,'SAM';...
                     11,'NFM';...
                     12,'DFM';...
                     20,'FDV';...
                     30,'RTTY'} ;
        mg ; % double transmitter mic gain 0-100
        nl ; % double slice A noise blanker 0-100
        nr ; % double slice A noise reduction on=1 off = 0
        pc ; % double PA drive level 0-100
        pf ; % double panadapter center frequency Hz
        rc ; % no value clear RIT freq, set pnly
        rd ; % double RIT decrement empty or 00000-99999
        rg ; % double RIT freq Hz
        rt ; % double RIT 0 = off, 1 = on
        ru ; % double RIT increment empty or 00000-99999
        rx = 0 ; % double RX mode set only
        sh ; % double DSP Filter hi cutoff index to shValues [0:11]
                %   col1 LSB,USB,CW,DIGU,DIGL  col2 AM
        shValues = [1400,1600,1800,2000,2200,2400,2600,2800,3000,3400,4000,5000;...
            2500,3000,4000,5000,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN]' ;
        sl ; % double DSP filter lo cutoff index to slValues [0:11]
                %   col1 LSB,USB,CW,DIGU,DIGL  col2 AM
        slValues = [0,50,100,200,300,400,500,600,700,800,900,1000;...
            0,100,200,500,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN]' ;
        sm ; % double [P1,P2] P1=0 slice index 0-7, P2= received strength dBm
        sw ; % double slice Tx flag 0=RxA or 1=RxB
        tx ; % double TX mode set only 0=RX  1=TX
        xc ; % no value clear XIT freq
        xg ; % double XIT freq Hz
        xs ; % double XIT enable state
        xt ; % double XIT 0 = off, 1 = on
        
        %% Sound
        wfFs = 24000 ; % % waveform file sample rate
        daxFs = 48000 ; % IQ and audio sample rate
        nBits = 24 ; % number of bits for each audio or IQ sample
        nChan = 1 ; % number of audio channels
        nTxChan = 1 ; % numbner of transmit audio channels
        audioDev ; % listing of sound card input and output devices 
        txAudioFlex ; % audioplayer object to send audio to Flex DAX
        rxAudioFlex ; % audiorecorder object to get audio from Flex DAX
    %     txIQFlex ; % audioplayer object to send IQ to Flex DAXIQ ** Future Use **
        rxIQFlex ; % audiorecorder object to receive IQ from Flex DAXIQ
        txDaxAudioNum = 1 ; % device number to use for TX audio
        rxDaxAudioNum = 1 ; % device number to use for RX audio
    %     txDaxIQNum = 1 ; % device number to use for TX IQ ** Future Use **
        rxDaxIQNum = 1 ; % device number to use for RX IQ
        txDaxAudioIdx ; % device number from daxAudioDevices matching
        rxDaxAudioIdx ; % device number from daxAudioDevices to use for RX audio
    %     txDaxIQIdx ; % device number from daxAudioDevices to use for TX IQ ** Future Use **
        rxDaxIQIdx ; % device number from daxAudioDevices to use for RX IQ
        txAudio ; % transmit waveform to soundcard audio output
        txAudioTime ; % double Playback time in seconds
        rxAudio ; % double receive waveform from soundcard audio input
        rxAudioTime ; % double Record time in seconds
        txIQ ; % transmit complex modulation in-phase and quadrature components complex
        rxIQ ; % sendreceive complex modulation in-phase and quadrature components complex
        txAudioFileName ;
        rxAudioFileName ;
        txIQFileName ;
        rxIQFileName ;

    end

    %% Common functions
    methods

        % Create serial object for radio control
        function serialObject(obj)
            obj.serialObj = serial(obj.serialPort,...
                'BaudRate',9600,...
                'Parity','None',...
                'StopBits',1,...
                'Terminator',';',...
                'TimeOut',3,...
                'BytesAvailableFCN',{@flex6700CAT_v5.flex6700CATRead,obj},...
                'Name',['flex6700-Serial-',obj.serialPort],...
                'Tag','serialObj') ;

            fopen(obj.serialObj) ;
        end

        % Send command to radio
        function radioCmd(obj)
            % Un-comment to see commands as sent to radio
%             disp(['writeData : ',obj.writeData])
            fprintf(obj.serialObj,obj.writeData) ;
            pause(0.1)
        end % radioCmd

        % Ready response from radio - used by serialObj BytesAvaliableFcn
        function radioCmdAns(obj)
            ba = obj.serialObj.BytesAvailable ;
            while ba ~= 0
                obj.readData = fgetl(obj.serialObj) ;
                radioResponse(obj) ;
                ba = obj.serialObj.BytesAvailable ;
            end
        end % radioCmdAns

        % Clear input buffer
        function clearRead(obj)
            bytesAvailable = get(obj.serialObj,'BytesAvailable') ;
            while bytesAvailable ~= 0
                radioCmdAns(obj)
                bytesAvailable = get(obj.serialObj,'BytesAvailable') ;
            end
        end % clearRead

        % Parse response from radio
        function radioResponse(obj)
            % Un-comment to see raw radio responses
%             disp(['readData : ',obj.readData])
            if strcmpi(obj.readData(1),'?')
                obj.readError = 1 ;
                disp(['readError : ',datestr(now,30),' : ',obj.readData,' : ',obj.writeData]) ;
            else
                obj.readError = 0 ;
                if strcmpi(obj.readData(1:2),'ZZ')  % Flex CAT Commands
                    obj.readData(1:2) = [] ;
                    zz = 1 ; % zz used to account for differences between ZZ and Kenwood commands
                else
                    zz = 0 ;
                end
                switch obj.readData(1:2)
                    case 'AG'
                        obj.ag = str2double(obj.readData(3:5)) ; % 0-100
                    case 'AI'
                        obj.ai = str2double(obj.readData(3)) ; % 0 = off, 1 = on
                    case 'DE'
                        obj.de = str2double(obj.readData(3)) ; % 0 = off, 1 = on
                    case 'FA'
                        obj.fa = str2double(obj.readData(3:13)) ; % Hz 11 digits
                    case 'FB'
                        obj.fb = str2double(obj.readData(3:13)) ; % Hz 11 digits
                    case 'FI'
                        obj.fi = str2double(obj.readData(3:4)) ; % 00-07
                    case 'FJ'
                        obj.fj = str2double(obj.readData(3:4)) ; % 00-07
                    case 'FR'
                        obj.fr = str2double(obj.readData(3)) ; 
                        % 0 no RxB or RxB present and controls TX
                        % 1 RxB present and RxA controls TX
                    case 'FT'
                        obj.ft = str2double(obj.readData(3)) ; % 0 set RxA TX flag, 1 set RxB TX flag
                    case 'GT'
                        if zz == 1
                            obj.gt = str2double(obj.readData(3)) ; % FlexCmd see gtLables
                        else
                            obj.gt = str2double(obj.readData(3:5)) ; % KWCmd see gtLables
                        end
                    case 'ID'
                        obj.id = str2double(obj.readData(3:5)) ; % see idLables
                    case 'IF'
                        obj.ifk.fa = str2double(obj.readData(3:13)) ; % VFO A Hz 11 digits
                        obj.ifk.fss = str2double(obj.readData(14:17)) ; % see fssLabels
                        obj.ifk.itf = str2double(obj.readData(18:23)) ; % RIT/XIT freq Hz (000000)
                        obj.ifk.rit = str2double(obj.readData(24)) ; % 0 = off, 1 = on
                        obj.ifk.xit = str2double(obj.readData(25)) ; % 0 = off, 1 = on
                        obj.ifk.cbn1 = str2double(obj.readData(26)) ; % not used = 00
                        obj.ifk.cbn2 = str2double(obj.readData(27:28)) ; % not used = 00
                        obj.ifk.mox = str2double(obj.readData(29)) ; % MOX 0 = off, 1 = on
                        obj.ifk.mode = str2double(obj.readData(30)) ; % see ModeLabelsK
                        obj.ifk.fr = str2double(obj.readData(31)) ;  % see case FR
                        obj.ifk.scan = str2double(obj.readData(32)) ; % not used = 0
                        obj.ifk.ft = str2double(obj.readData(33)) ; % see case FT
                        obj.ifk.ctcss = str2double(obj.readData(34)) ; % not used = 0
                        obj.ifk.tone = str2double(obj.readData(35:36)) ; % not used = 00
                        obj.ifk.shift = str2double(obj.readData(37)) ; % not used = 0
                    case 'KS'
                        obj.ks = str2double(obj.readData(3:5)) ; % key speed 5 to 50
                    case 'KY'
                        obj.ky = str2double(obj.readData(3)) ; % Buffer available 0=Yes 1=No
                    case 'LE'
                        obj.le = str2double(obj.readData(3:5)) ; % 0-100
                    case 'MD'
                        if zz == 1
                            obj.md = str2double(obj.readData(3:4)) ; % see modeLabel
                        else
                            obj.md = str2double(obj.readData(3)) ; % see modeLabel
                        end
                    case 'ME'
                        obj.me = str2double(obj.readData(3:4)) ; % see modeLabel
                    case 'MG'
                        obj.mg = str2double(obj.readData(3:5)) ; % 0-100
                    case 'NL'
                        obj.nl = str2double(obj.readData(3:5)) ; % 000-100
                    case 'NR'
                        obj.nr = str2double(obj.readData(3)) ; % 0 = Off, 1 = On double
                    case 'PC'
                        obj.pc = str2double(obj.readData(3:5)) ; % 000 to 100
                    case 'PF'
                        obj.pf = str2double(obj.readData(3:13)) ; % 00065000000 to 00000010000
                    case 'RC'
                        obj.rc = NaN ; % set only
                    case 'RD'
                        obj.rd = NaN ; % set only
                    case 'RG'
                        obj.rg = str2double(obj.readData(3:8)) ; % + or - 00000 to 99999 double
                    case 'RT'
                        obj.rt = str2double(obj.readData(3)) ; % 0 = off, 1 = on
                    case 'RU'
                        obj.ru = NaN ; % set only
                    case 'RX'
                        if zz==1
                            obj.rx = str2double(obj.readData(3)) ;  % 0 = off, 1 = on
                        else
                            obj.rx = NaN ; % set only
                        end
                    case 'SH'
                        obj.sh = str2double(obj.readData(3:4)) ; % see dspHiValue
                    case 'SL'
                        obj.sl = str2double(obj.readData(3:4)) ; % see dspLoValue
                    case 'SM'
                        if zz == 1
                             obj.sliceNum = str2double(obj.readData(3)) ; % 0-7 slice index
                             obj.sm(obj.sliceNum+1) = str2double(obj.readData(4:6))/2-140 ; % 000-260 becomes dBm
                        else
                            obj.sm(1) = str2double(obj.readData(3:6)) ; % 0000-0030
                        end
                    case 'SW'
                        obj.sw = str2double(obj.readData(3)) ; % 0 = off, 1 = on
                    case 'TX'
                        if zz == 1
                            obj.tx = str2double(obj.readData(3)) ;
                        else
                            obj.tx = NaN ; % set only
                        end
                    case 'XC'
                        obj.xc = NaN ; % set only
                    case 'XG'
                        obk.xg = str2double(obj.readData(3:8)) ; % + or - 00000 to 99999 double
                    case 'XS'
                        obj.xs = str2double(obj.readData(3)) ; % 0 = off, 1 = on
                    case 'XT'
                        obj.xt = str2double(obj.readData(3)) ; % 0 = off, 1 = on
                    otherwise
                        obj.readText = obj.readData ; 
                        obj.clearRead ;
                end
            end
        end
    end

    %% General functions
    methods  % General functions
        % Create Maidenhead grid squares for Rx and Tx sites
        function gridSquare = maidenhead(lat,lon)
            mhLon=lon+180;
            mhLat=lat+90;
            l1 = floor(mhLon/20)+1; % 20 deg lon
            mh1 = char(l1+64); % letter 1
            l2 = floor(mhLat/10)+1; % 10 deg lat
            mh2 = char(l2+64);
            n1=floor(mod(mhLon,20)/2); % 2 deg lon
            mh3=num2str(n1);
            n2=floor(mod(mhLat,10)/1); % 1 deg lat
            mh4=num2str(n2);
            l5=floor(mod(mhLon,2)*60/5)+1; % 5 min lon
            mh5=caseconvert(char(l5+64),'lower');
            l6=floor(mod(mhLat,1)/1*60/2.5)+1; % 2.5 min lat
            mh6=caseconvert(char(l6+64),'lower');
            gridSquare = strcat(mh1,mh2,mh3,mh4,mh5,mh6) ; 
        end

        function setGridSquares(obj)
            if isempty(obj.rxLat) || isempty(obj.rxLon)
                obj.rxLat = 30.444901 ;
                obj.rxLon = -97.707916 ; % Flex Radio
            end
            if isempty(obj.txLat) || isempty(obj.txLon)
                obj.txLat = obj.rxLat ; 
                obj.txLon = obj.rxLon ;
            end
            obj.rxGrid = maidenhead(obj.rxLat,obj.rxLon) ;
            obj.txGrid = maidenhead(obj.txLat,obj.txLon) ;
        end
        
        function initialize(obj)
            obj.clearRead ;
            obj.in1 = 0 ; obj.setZZRX ; % turn off transmitter
            obj.in1 = 1 ; obj.setAI ; obj.getAI ;
            obj.in1 = 0 ; obj.setZZDE ; obj.getZZDE ;
            obj.getZZAG ;
            obj.getZZFA ;
            obj.getZZFI ;
            obj.getFR ;
            obj.getFT ;
            obj.in1 = 3 ; obj.setZZGT ; obj.getGT ;
            obj.getID ;
            obj.getZZIF ;
            obj.getKS ;
            obj.getZZMD ;
            obj.getZZNL ;
            obj.getZZNR ;
            obj.getZZPC ;
            obj.getZZPF ;
            obj.setZZRC ;
            obj.in1 = 0 ; obj.setZZRT ;
            obj.getSH ;
            obj.getSL ;
            obj.getZZSW ;
            obj.setZZXC ;
            obj.in1 = 0 ; obj.setZZXS ;
        end
        
         function cmdTest(obj)
            obj.clearRead ;
            obj.in1 = 0 ; obj.setZZRX ; % turn off transmitter
            obj.getZZAG ;
            obj.in1 = 50 ; obj.setZZAG ;
            obj.getZZAI ;
            obj.in1 = 1 ; obj.setZZAI ;
            obj.getAI ;
            obj.in1 = 1 ; obj.setAI ;
            obj.getZZDE ;
            obj.in1 = 0 ; obj.setZZDE ;
            obj.getZZFA ;
            obj.in1 = 14313000 ; obj.setZZFA ;
            obj.in1 = 7290000 ; obj.setZZFA
            obj.getFA ;
            obj.in1 = 14310000 ; obj.setFA ;
            obj.in1 = 7265000 ; obj.setFA
            obj.getZZFI ;
            obj.in1 = 3 ; obj.setZZFI ;
            obj.in1 = 4 ; obj.setZZFI ;
            obj.getFR ;
            obj.getFT ;
            obj.in1 = 0 ; obj.setFT ;
            obj.getZZGT ;
            obj.in1 = 4 ; obj.setZZGT ;
            obj.in1 = 3 ; obj.setZZGT ;
            obj.getGT ;
            obj.in1 = 4 ; obj.setGT ;
            obj.in1 = 3 ; obj.setGT ;
            obj.getID ;
            obj.getZZIF ;
            obj.getIF ;
            obj.getKS ;
            obj.in1 = 19 ; obj.setKS ;
            obj.getKY ;
            obj.in1 = 'DE KR4K EM00TH' ; obj.setKY ;
            obj.getZZLE ;
            obj.in1 = 50 ; obj.setZZLE ;
            obj.getZZMD ;
            obj.in1 = 0 ; obj.setZZMD ;
            obj.in1 = 1 ; obj.setZZMD ;
            obj.getMD ;
            obj.in1 = 9 ; obj.setMD ;
            obj.in1 = 1 ; obj.setMD ;
            obj.getZZMG ;
            obj.in1 = 50 ; obj.setZZMG ;
            obj.getZZNL ;
            obj.in1 = 65 ; obj.setZZNL ;
            obj.in1 = 1 ; obj.setZZNL ;
            obj.getZZNR ;
            obj.in1 = 1 ; obj.setZZNR ;
            obj.in1 = 0; obj.setZZNR ;
            obj.getZZPC ;
            obj.in1 = 100 ; obj.setZZPC ;
            obj.in1 = 24 ; obj.setZZPC ;
            obj.getPC ;
            obj.in1 = 20 ; obj.setPC ;
            obj.getZZPF ;
            obj.in1 = 7265000 ; obj.setZZPF ;
            obj.in1 = 7250000 ; obj.setZZPF ;
            obj.in1 = 1 ; obj.setZZRT ;
            obj.setZZRC ;
            obj.getZZRG ;
            obj.setZZRD ;
            obj.getZZRG
            obj.in1 = 5 ; obj.setZZRD ;
            obj.getZZRG ;
            obj.in1 = -45 ; obj.setZZRG ;
            obj.getZZRG ;
            obj.setZZRU ;
            obj.getZZRG ;
            obj.in1 = 75 ; obj.setZZRU ;
            obj.getZZRG ;
            obj.setZZRC ;
            obj.in1 = 0 ; obj.setZZRT ;
            obj.in1 = 1 ; obj.setRT ;
            obj.setRC ;
            obj.setRD ;
            obj.in1 = 5 ; obj.setRD ;
            obj.setRU ;
            obj.in1 = 75 ; obj.setRU ;
            obj.setRC ;
            obj.in1 = 0 ; obj.setRT ;
            obj.getZZRX ;
            obj.in1 = 1 ; obj.setZZRX ;
            obj.in1 = 0 ; obj.setZZRX ;
            obj.setRX ;
            obj.getSH ;
            obj.in1 = 10 ; obj.setSH ;
            obj.in1 = 7 ; obj.setSH ;
            obj.getSL ;
            obj.in1 = 6 ; obj.setSL ;
            obj.in1 = 2 ; obj.setSL ;
            obj.getZZSM ;
            obj.getSM ;
            obj.getZZSW ;
            obj.in1 = 0 ; obj.setZZSW ;
            obj.getZZTX ;
            obj.in1 = 1 ; obj.setZZTX ;
            obj.in1 = 0 ; obj.setZZTX ;
            obj.setTX ; obj.setRX ;
            obj.in1 = 1 ; obj.setZZXG ;
            obj.setZZXC ;
            obj.in1 = -40 ; obj.setZZXG ;
            obj.setZZXC ;
            obj.in1 = 0 ; obj.setZZXS ;
            obj.getXT ;
            obj.in1 = 1 ; obj.setXT ;
            obj.in1 = 0 ; obj.setXT ;
        end
    end

    methods % Soundcard interface
       %{
    Soundcard input examples
    Primary Sound Capture Driver (Windows DirectSound)
    DAX RESERVED AUDIO TX 8 (DAX TX Audio) (Windows DirectSound)
    DAX RESERVED AUDIO TX 5 (DAX TX Audio) (Windows DirectSound)
    DAX IQ RX 4 (DAX RX IQ) (Windows DirectSound)
    DAX RESERVED AUDIO TX 2 (DAX TX Audio) (Windows DirectSound)
    DAX IQ RX 3 (DAX RX IQ) (Windows DirectSound)
    DAX Audio RX 8 (DAX RX Audio) (Windows DirectSound)
    DAX RESERVED AUDIO TX 4 (DAX TX Audio) (Windows DirectSound)
    DAX IQ RX 1 (DAX RX IQ) (Windows DirectSound)
    DAX Audio RX 1 (DAX RX Audio) (Windows DirectSound)
    DAX Audio RX 6 (DAX RX Audio) (Windows DirectSound)
    DAX Audio RX 5 (DAX RX Audio) (Windows DirectSound)
    DAX RESERVED AUDIO TX 7 (DAX TX Audio) (Windows DirectSound)
    DAX Audio RX 4 (DAX RX Audio) (Windows DirectSound)
    DAX Audio RX 7 (DAX RX Audio) (Windows DirectSound)
    DAX Audio RX 2 (DAX RX Audio) (Windows DirectSound)
    DAX Audio RX 3 (DAX RX Audio) (Windows DirectSound)
    DAX IQ RX 2 (DAX RX IQ) (Windows DirectSound)
    DAX RESERVED AUDIO TX 1 (DAX TX Audio) (Windows DirectSound)

    Soundcard output examples
    Primary Sound Driver (Windows DirectSound)
    Speakers (Realtek High Definition Audio) (Windows DirectSound)
    DAX RESERVED IQ RX 1 (DAX RX IQ) (Windows DirectSound)
    DAX Audio TX 1 (DAX TX Audio) (Windows DirectSound)
    DAX Audio TX 5 (DAX TX Audio) (Windows DirectSound)
    DAX RESERVED AUDIO RX 6 (DAX RX Audio) (Windows DirectSound)
    DAX RESERVED IQ RX 3 (DAX RX IQ) (Windows DirectSound)
    DAX RESERVED AUDIO RX 4 (DAX RX Audio) (Windows DirectSound)
    DAX RESERVED AUDIO RX 5 (DAX RX Audio) (Windows DirectSound)
    DAX Audio TX 8 (DAX TX Audio) (Windows DirectSound)
    DAX Audio TX 6 (DAX TX Audio) (Windows DirectSound)
    DAX RESERVED AUDIO RX 2 (DAX RX Audio) (Windows DirectSound)
    DAX RESERVED IQ RX 2 (DAX RX IQ) (Windows DirectSound)
    DAX Audio TX 4 (DAX TX Audio) (Windows DirectSound)
    DAX RESERVED AUDIO RX 7 (DAX RX Audio) (Windows DirectSound)
    DAX RESERVED AUDIO RX 1 (DAX RX Audio) (Windows DirectSound)
    DAX RESERVED AUDIO RX 3 (DAX RX Audio) (Windows DirectSound)
    DAX Audio TX 3 (DAX TX Audio) (Windows DirectSound)
    DAX RESERVED AUDIO RX 8 (DAX RX Audio) (Windows DirectSound)
    DAX RESERVED IQ RX 4 (DAX RX IQ) (Windows DirectSound)
    DAX Audio TX 2 (DAX TX Audio) (Windows DirectSound)
    DAX Audio TX 7 (DAX TX Audio) (Windows DirectSound)    
    %}

        function getDaxAudioDevices(obj)
            obj.audioDev = audiodevinfo ;
            % Find specified DAX transmit channel
            for idx = 1:length(obj.audioDev.output)
                if ~isempty(strfind(obj.audioDev.output(idx).Name,['DAX Audio TX ',num2str(obj.txDaxAudioNum,'%1.0f')]))
                    obj.txDaxAudioIdx = idx ;
                elseif ~isempty(strfind(obj.audioDev.output(idx).Name,['DAX Audio RX ',num2str(obj.rxDaxAudioNum,'%1.0f')]))
                    obj.rxDaxAudioIdx = idx ;
    %             elseif ~isempty(strfind(obj.audioDev.output(idx).Name,['DAX IQ TX ',num2str(obj.txDaxIQNum,'%1.0f')]))
    %                 obj.txDaxIQIdx = idx ;
                elseif ~isempty(strfind(obj.audioDev.output(idx).Name,['DAX IQ RX ',num2str(obj.rxDaxIQNum,'%1.0f')]))
                    obj.rxDaxIQIdx = idx ;
                end
            end
        end

        function iq2Audio(obj)
            % Narrowband Single Channel DAX audio
            obj.txAudio = NaN*ones(2,size(obj.txIQ,2)) ;
            if obj.nTxChan == 1 % Create single audio voltage from IQ waveform
                obj.txAudio = abs(obj.txIQ) .* cos(angle(obj.txIQ)) ; % switch from complex IQ to amplitude to phase
                obj.txAudio = 1/max(obj.txAudio).*obj.txAudio ; % Normalize to max 1 volt P2P
            elseif obj.nTxChan == 2 % Lch = I, Rch = Q, requires raw_iq_enabled=1 via TELNET
                obj.txAudio(1,:) = real(obj.txIQ) ;
                obj.txAudio(2,:) = imag(obj.txIQ) ;
                obj.txAudio = 1/max(max(obj.txAudio)).*obj.txAudio ;
            end
        % adjust for DAX sample rate
            if obj.wfFs ~= obj.daxFs
                obj.txAudio = resample(obj.txAudio,obj.daxFs,obj.wfFs) ;
            end
        end

        %% Send and receive audio or IQ
        function getAudio(obj) % receive audio object from Flex 6700
            if isempty(obj.rxAudioTime)
                obj.rxAudioTime = 10 ; % Default recording time 10 seconds
            end
            obj.rxAudioFlex = audiorecorder(obj.daxFs,obj.nBits,obj.nChan) ;
            recordblocking(obj.rxAudioFlex,obj.rxAudioTime + 0.1) ; % record 
            obj.rxAudio = getaudiodata(obj.rxAudioFlex) ; % Store recording
        end

        function setAudio(obj) % send audio object to Flex 6700
            obj.txAudioTime = length(obj.txAudio)/obj.daxFs ; % Playback time in seconds
            obj.txAudioFlex = audioplayer(obj.txAudio,...
                obj.daxFs,...
                obj.nBits,...
                obj.audioDev.output(obj.txDaxAudioIdx).ID) ; % uses the audio device identified by ID for output.
            tic ; % Start time on air counting
            playblocking(obj.txAudioFlex) ; % send audio stream to 6700 via DAX
            onAir = isplaying(obj.txAudioFlex) ; % Is audio still going
            while toc < obj.txTimeLimit + 0.25 && onAir % Is Tx length less than max Tx time + 025 S AND is audio still going
                onAir = isplaying(obj.txAudioFlex) ;
            end
        end

    %     function getIQ(obj) % receive IQ object from Flex 6700
    %         
    %     end
    %     
    %     function setIQ(obj) % send IQ to Flex 6700
    %         ** Future Capability **
    %     end
    end

    %% Flex CAT Commands
    methods
        %% Slice A audio audio gain
        function getZZAG(obj)
            obj.writeData = 'ZZAG' ;
            radioCmd(obj) ;
        end
        
        function setZZAG(obj) % 0-100
            if isempty(obj.in1) || obj.in1 < 0 || obj.in1 > 100; 
                obj.in1 = 50; % default
            end
            obj.writeData = ['ZZAG',num2str(obj.in1,'%03.0f')] ;
            radioCmd(obj) ;
        end
               
        %% Auto Information Mode
        function getZZAI(obj)
            obj.writeData = 'ZZAI' ;
            radioCmd(obj) ;
        end
        
        function setZZAI(obj)
            if isempty(obj.in1) || obj.in1 ~= 0 
                obj.in1 = 1; % default
            end
            obj.writeData = ['ZZAI',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj) ;
        end
        
        function getAI(obj)
            obj.writeData = 'AI' ;
            radioCmd(obj) ;
        end
        
        function setAI(obj)
            if isempty(obj.in1) || obj.in1 ~= 0 
                obj.in1 = 1; % default
            end
            obj.writeData = ['AI',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj) ;
        end
        
        %% Set or read Receiver Diversity mode (6700 only)
        function getZZDE(obj)
            obj.writeData = 'ZZDE' ;
            radioCmd(obj) ;
        end
        
        function setZZDE(obj)
            if isempty(obj.in1) || obj.in1 ~= 1; 
                obj.in1 = 0; % default
            end
            obj.writeData = ['ZZDE',num2str(obj.in1,'%1.0f')] ;
            radioCmd(obj) ;
        end
        
        %% Set or read slice frequency, A=00 or B=01
        function getZZFA(obj)
            % Only works on slices "A" = 00
            obj.writeData = 'ZZFA' ;
            radioCmd(obj) ;
        end
        
        function setZZFA(obj)
            if isempty(obj.in1) || obj.in1 < 10000 || obj.in1 > 30000000
                obj.in1 = obj.defaultFreqHz ;
            end
            % Only works on slice "A" = 00
            obj.writeData = ['ZZFA',num2str(obj.in1,'%011.0f')] ; % in1 Hz
            radioCmd(obj)
        end
        
        function getFA(obj)
            % Only works on slice "A" = 00
            obj.writeData = 'FA' ;
            radioCmd(obj)
        end
        
        function setFA(obj)
            % Only works on slice "A" = 00
            if isempty(obj.in1) || obj.in1 < 10000 || obj.in1 > 30000000
                obj.in1 = obj.defaultFreqHz ;
            end
            
            obj.writeData = ['FA',num2str(obj.in1,'%011.0f')] ; % in1 Hz
            radioCmd(obj)
        end
        
        function getZZFB(obj)
            % Only works on slice "B" = 01
            obj.writeData = 'ZZFB' ;
            radioCmd(obj) ;
        end
        
        function setZZFB(obj)
            % Only works on slice "B" = 01
            if isempty(obj.in1) || obj.in1 < 10000 || obj.in1 > 30000000
                obj.in1 = obj.defaultFreqHz ;
            end
            obj.writeData = ['ZZFB',num2str(obj.in1,'%011.0f')] ; % in1 Hz
            radioCmd(obj)
        end
        
        function getFB(obj)
            % Only works on slice "B" = 01
            obj.writeData = 'FB' ;
            radioCnd(obj)
        end
        
        function setFB(obj)
            % Only works on slice "B" = 01
            if isempty(obj.in1) || obj.in1 < 10000 || obj.in1 > 30000000
                obj.in1 = obj.defaultFreqHz ;
            end
            
            obj.writeData = ['FB',num2str(obj.in1,'%011.0f')] ; % in1 Hz
            radioCnd(obj)
        end
        
        %% Receiver DSP filters
        % ZZFI Sets or reads RX A DSP Filter, ZZFJ Sets or reads RX B DSP Filter
        function getZZFI(obj)
            % Only works on slice "A" = 00
            obj.writeData = 'ZZFI' ;
            radioCmd(obj) ;
        end
        
        function setZZFI(obj)
            % Only works on slice "A" = 00
            obj.writeData = ['ZZFI',num2str(obj.in1,'%02.0f')] ;
            radioCmd(obj)
        end
        
        function getZZFJ(obj)
            % Only works on slice "B" = 01
            obj.writeData = 'ZZFJ' ;
            radioCmd(obj) ;
        end
        
        function setZZFJ(obj)
            % Only works on slice "B" = 00
            obj.writeData = ['ZZFJ',num2str(obj.in1,'%02.0f')] ;
            radioCmd(obj)
        end
        
        %% Receiver Rx A/Rx B transmit flags
        function getFR(obj)
            obj.writeData = 'FR' ;
            radioCmd(obj) ;
        end
        
        function setFR(obj)
            if isempty(obj.in1) || obj.in1 ~= 1
                obj.in1 = 0 ; % RX A TX flag
            end
            obj.writeData = ['FR',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj)
        end
        
         function getFT(obj)
            obj.writeData = 'FT' ;
            radioCmd(obj) ;
        end
        
        function setFT(obj)
             if isempty(obj.in1) || ~any([0,1] == obj.in1)
                obj.in1 = 0 ; % RX A TX flag
            end
            obj.writeData = ['FT',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj)
        end


        %% Receiver AGC
        % ZZGT Sets or reads the AGC Mode
        function getZZGT(obj)
            obj.writeData = 'ZZGT' ;
            radioCmd(obj) ;
        end
        
        function setZZGT(obj)
            if isempty(obj.in1) || ~any([0,2,3,4] == obj.in1)
                obj.in1 = 3 ; % default medium
            end
            obj.writeData = ['ZZGT',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj) ;
        end
        
        function getGT(obj)
            obj.writeData = 'GT' ;
            radioCmd(obj) ;
        end
        
        function setGT(obj)
            if isempty(obj.in1) || ~any([0,2,3,4] == obj.in1)
                obj.in1 = 3 ; % default medium
            end
            
            obj.writeData = ['GT',num2str(obj.in1,'%03.0f')] ;
            radioCmd(obj) ;
        end
        
        %% Receiver ID number
        function getID(obj)
            obj.writeData = 'ID' ;
            radioCmd(obj) ;
        end

        %% Transceiver status query
        function getZZIF(obj)
            obj.writeData = 'ZZIF' ;
            radioCmd(obj) ;
        end
        
        function getIF(obj)
            obj.writeData = 'IF' ;
            radioCmd(obj) ;
        end
        
        %% CW keying
        % Keying speed
        function getKS(obj)
            obj.writeData = 'KS' ;
            radioCmd(obj) ;
        end
        
       function setKS(obj)
           % set limits
           if ~isempty(obj.in1) && (obj.in1 < 5 || obj.in1 > 50)
               obj.in1 = 20 ;
           end
           
            obj.writeData = ['KS',num2str(obj.in1,'%03.0f')] ;
            radioCmd(obj) ;
       end
       
       % CWX buffer
       function getKY(obj)
            obj.writeData = 'KY' ;
            radioCmd(obj) ;
       end
       
       function setKY(obj)
           % ensure 24 minimum characters
            charCount = length(obj.in1) ;
            while charCount < 24
                obj.in1 = [obj.in1,' '] ;
                charCount = length(obj.in1) ;
            end
            obj.writeData = ['KY0',obj.in1] ;
            radioCmd(obj) ;
       end

       %% Slice B audio audio gain
        function getZZLE(obj)
            obj.writeData = 'ZZLE' ;
            radioCmd(obj) ;
        end
        
        function setZZLE(obj) % 0-100
            if isempty(obj.in1) || obj.in1 < 0 || obj.in1 > 100; 
                obj.in1 = 50; % default
            end
            obj.writeData = ['ZZLE',num2str(obj.in1,'%03.0f')] ;
            radioCmd(obj) ;
        end

        %% Mode
        % ZZMD Sets or reads RX A DSP Mode
        function getZZMD(obj)
            obj.writeData = 'ZZMD' ;
            radioCmd(obj) ;
        end
        
        function setZZMD(obj)
            if isempty(obj.in1) || ~any(cell2mat(obj.mdValues(:,1))==obj.in1)
                obj.in1 = 01; % default USB
            end
            obj.writeData = ['ZZMD',num2str(obj.in1,'%02.0f')] ;
            radioCmd(obj) ;
        end

        % ZZME Sets or reads RX B DSP Mode
        function getZZME(obj)
            obj.writeData = 'ZZME' ;
            radioCmd(obj) ;
        end
        
        function setZZME(obj)
            if isempty(obj.in1) || ~any(cell2mat(obj.mdValues(:,1))==obj.in1)
                obj.in1 = 01; % default USB
            end
            obj.writeData = ['ZZME',num2str(obj.in1,'%02.0f')] ;
            radioCmd(obj) ;
        end
        
        function getMD(obj)
            obj.writeData = 'MD' ;
            radioCmd(obj) ;
        end
        
        function setMD(obj)
            % Check proper values
            if ~any(obj.in1==[1,2,3,4,5,6,9])
                obj.in1 = 2 ; % dafauly USB
            end
            
            obj.writeData = ['MD',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj) ;
        end
        
        %% Transmit Mic Level
        function getZZMG(obj)
            obj.writeData = 'ZZMG' ;
            radioCmd(obj) ;
        end
        
        function setZZMG(obj) % 0-100
            if isempty(obj.in1) || obj.in1 < 0 || obj.in1 > 100; 
                obj.in1 = 50; % default
            end
            obj.writeData = ['ZZMG',num2str(obj.in1,'%03.0f')] ;
            radioCmd(obj) ;
        end
 
        %% Noise Blanker and Noise Reduction
        % Noise blanker slice A
        function getZZNL(obj)
            obj.writeData = 'ZZNL' ;
            radioCmd(obj) ;
        end
        
        function setZZNL(obj)
            if isempty(obj.in1) || obj.in1 < 0 || obj.in1 > 100; 
                obj.in1 = 50; % default
            end
            obj.writeData = ['ZZNL',num2str(obj.in1,'%03.0f')] ;
            radioCmd(obj) ;
        end

        %  Noise Reduction (NR) Slice A
        function getZZNR(obj)
            obj.writeData = 'ZZNR' ;
            radioCmd(obj) ;
        end
        
        function setZZNR(obj)
            if isempty(obj.in1) || obj.in1 ~= 1; 
                obj.in1 = 0; % default
            end
            obj.writeData = ['ZZNR',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj) ;
        end

        %% PA drive
        % ZZPC Sets or reads the PA drive level
        function getZZPC(obj)
            obj.writeData = 'ZZPC' ;
            radioCmd(obj) ;
        end
        
        function setZZPC(obj)
           % Check limits
            if isempty(obj.in1) || obj.in1 < 0 || obj.in1 > 100
                obj.in1 = 10 ; % default 10 10W
            end
            
            obj.writeData = ['ZZPC',num2str(obj.in1,'%03.0f')] ;
            radioCmd(obj) ;
        end
        
        function getPC(obj)
            obj.writeData = 'PC' ;
            radioCmd(obj) ;
        end
        
        function setPC(obj)
            % Check limits
            if isempty(obj.in1) || obj.in1 < 0 || obj.in1 > 100
                obj.in1 = 10 ; % default 10 10W
            end
            
            obj.writeData = ['PC',num2str(obj.in1,'%03.0f')] ;
            radioCmd(obj) ;
        end

        %% PanAdapter center freq
        %   Currently only operates on Slice 0 (RX A)
        function getZZPF(obj)
            obj.writeData = 'ZZPF' ;
            radioCmd(obj) ;    
        end 
        
        function setZZPF(obj)
            if isempty(obj.in1) || obj.in1 < 10000 || obj.in1 > 65000000
                obj.in1 = obj.defaultFreqHz ;
            end
            
            obj.writeData = ['ZZPF',num2str(obj.in1,'%011.0f')] ;
            radioCmd(obj) ;
        end

        %% RIT
        % ZZRC Clear the RIT Frequency
        function setZZRC(obj)
            obj.writeData = 'ZZRC' ;
            radioCmd(obj) ;
        end
        
        function setRC(obj)
            obj.writeData = 'RC' ;
            radioCmd(obj) ;
        end 

        % ZZRD Decrement the RIT frequency
        function setZZRD(obj)
            % Limit check
            if ~isempty(obj.in1)  && (obj.in1 < 0 || obj.in1 > 99999)
                obj.in1 = 0 ; 
            end ; % end limit check

            if isempty(obj.in1)
                obj.writeData = 'ZZRD' ;
            else
                obj.writeData = ['ZZRD',num2str(obj.in1,'%05.0f')] ;
            end
            radioCmd(obj) ;
        end
        
        function setRD(obj) % slice A
            % Limit check
            if ~isempty(obj.in1)  && (obj.in1 < 0 || obj.in1 > 99999)
                obj.in1 = 0 ; 
            end ; % end limit check

            if isempty(obj.in1)
                obj.writeData = 'RD' ;
            else
                obj.writeData = ['RD',num2str(obj.in1,'%05.0f')] ;
            end
            radioCmd(obj) ;
        end

        % ZZRG Set/Read the RIT Frequency
        function getZZRG(obj)
            obj.writeData = 'ZZRG' ;
            radioCmd(obj) ;
        end
        
        function setZZRG(obj)
            % Limit check
            if ~isempty(obj.in1) && (obj.in1 < -99999 || obj.in1 > 99999)
                obj.in1 = 0 ; 
            end ; % end limit check

            obj.writeData = ['ZZRG',num2str(obj.in1,'%+06.0f')] ;
            radioCmd(obj) ;
        end

        % ZZRT Enables/Disables RIT
        function getZZRT(obj)
            obj.writeData = 'ZZRT' ;
            radioCmd(obj) ;
        end
        
        function setZZRT(obj)
            obj.writeData = ['ZZRT',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj) ; 
        end
        
        function getRT(obj)
            obj.writeData = 'RT' ;
            radioCmd(obj) ;
        end
        
        function setRT(obj)
            obj.writeData = ['RT',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj) ; 
        end

        % ZZRU Increment the RIT frequency
        function setZZRU(obj)
            if ~isempty(obj.in1) && (obj.in1 < 0 || obj.in1 > 99999)
                obj.in1 = 0 ; 
            end ; % end limit check
            
            if isempty(obj.in1)
                obj.writeData = 'ZZRU' ;
            else
                obj.writeData = ['ZZRU',num2str(obj.in1,'%05.0f')] ;
            end
            radioCmd(obj) ;
        end
        
        function setRU(obj)
            if ~isempty(obj.in1) && (obj.in1 < 0 || obj.in1 > 99999)
                obj.in1 = 0 ; 
            end ; % end limit check
            
            if isempty(obj.in1)
                obj.writeData = 'RU' ;
            else
                obj.writeData = ['RU',num2str(obj.in1,'%05.0f')] ;
            end
            radioCmd(obj) ;
        end

        %% MOX
        % ZZRX Sets or reads the MOX button
        function getZZRX(obj)
            obj.writeData = 'ZZRX' ;
            radioCmd(obj) ;
        end
        
        function setZZRX(obj)
            if isempty(obj.in1) || obj.in1 ~= 1
                obj.in1 = 0 ; % default off
            end
            obj.writeData = ['ZZRX',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj) ; 
        end
        
        function setRX(obj)
            obj.writeData = 'RX' ;
            radioCmd(obj) ; 
        end
        %% DSP filter settings
        
        % High filter cutoff
        function getSH(obj)
            obj.writeData = 'SH' ;
            radioCmd(obj) ;
        end
        
        function setSH(obj)
            % Check values
            if isempty(obj.in1) || obj.in1 < 0 || obj.in1 > 11
                obj.in1 = 3 ; % default 2 kHz or 5 kHz AM
            end
            
            obj.writeData = ['SH',num2str(obj.in1,'%02.0f')] ;
            radioCmd(obj) ; 
        end
  
        % Low filter cutoff
        function getSL(obj)
            obj.writeData = 'SL' ;
            radioCmd(obj) ;
        end
        
        function setSL(obj)
            % Check values
            if isempty(obj.in1) || obj.in1 < 0 || obj.in1 > 11
                obj.in1 = 2 ; % default 100 Hz or 500 Hz AM
            end
            
            obj.writeData = ['SL',num2str(obj.in1,'%02.0f')] ;
            radioCmd(obj) ; 
        end

        %% S-Meter
        % ZZSM Read the S-Meter
        function getZZSM(obj)
            if isempty(obj.in1) || obj.in1 < 0 || obj.in1 > 7
                obj.in1 = 0 ; % slice 0
            end
            
            obj.writeData = ['ZZSM',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj) ;
        end
        
        function getSM(obj)
            obj.writeData = 'SM0' ;
            radioCmd(obj) ;
        end

        %% Transmit slice
        % ZZSW Sets or reads the Transmit Flag (RX A or RX B)
        function getZZSW(obj)
            obj.writeData = 'ZZSW' ;
            radioCmd(obj) ;
        end
        
        function setZZSW(obj)
            if isempty(obj.in1) || obj.in1 ~= 1
                obj.in1 = 0 ; % default slice 0 RX A
            end
            
            obj.writeData = ['ZZSW',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj) ; 
        end

        %% Tx state = Mox
        % ZZTX Sets or reads the radio transmit state (MOX)
        function getZZTX(obj)
            obj.writeData = 'ZZTX' ;
            radioCmd(obj) ;
        end
        
        function setZZTX(obj)
            if isempty(obj.in1) || obj.in1 ~= 1
                obj.in1 = 0 ; % default receive mode
            end
            
            obj.writeData = ['ZZTX',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj) ; 
        end
        
        function setTX(obj)
            
            obj.writeData = 'TX' ; 
            radioCmd(obj) ; 
        end
        
        %% XIT
        % ZZXC Clear the XIT Frequency
        function setZZXC(obj)
            obj.writeData = 'ZZXC' ;
            radioCmd(obj) ;
        end

        % ZZXG Set/Read the XIT Frequency
        function getZZXG(obj)
            obj.writeData = 'ZZXG' ;
            radioCmd(obj) ;
        end
        
        function setZZXG(obj)
            % Limit check
            if ~isempty(obj.in1) && (obj.in1 < -99999 || obj.in1 > 99999)
                obj.in1 = 0 ; 
            end ; % end limit check

            obj.writeData = ['ZZXG',num2str(obj.in1,'%+06.0f')] ;
            radioCmd(obj) ;
        end

        % ZZXS Enables/Disables XIT
        function getZZXS(obj)
            obj.writeData = 'ZZXS' ;
            radioCmd(obj) ;
        end
        
        function setZZXS(obj)
            if isempty(obj.in1) || obj.in1 ~= 1
                obj.in1 = 0 ; % default off
            end
            obj.writeData = ['ZZXS',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj) ; 
        end
        
        function getXT(obj)
            obj.writeData = 'XT' ;
            radioCmd(obj) ;
        end
        
        function setXT(obj)
            obj.writeData = ['XT',num2str(obj.in1,'%01.0f')] ;
            radioCmd(obj) ;
        end
  
    end

    methods (Static)
        
        % serial object BytesAvailableFcn callback
        function flex6700CATRead(~,~,obj)
            radioCmdAns(obj) ;
            return
        end
        
        % Handle Serial communications error
        function flex6700CATReadError(~,~,obj)
            obj.radioReadError = fscanf(obj.serialObj) ;
            disp('*** *** Error FCN *** ***')
            disp(obj.radioReadError) ;
            obj.radioCmdObjError = get(obj.serialObj) ;
            obj.radioClearRead(obj) ;
            set(obj.serialObj,...
            'BytesAvailableFcnCount',4,...
            'BytesAvailableFCN',{@flex6700CAT_v5.flex6700CATRead,obj}) ;
        end    
    end
end