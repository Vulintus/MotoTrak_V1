function serial_codes = Load_MotoTrak_Serial_Codes(ver)

%LOAD_MOTOTRAK_SERIAL_CODES.m
%
%	Vulintus, Inc.
%
%	MotoTrak serial communication code library.
%
%	Library V2 documentation:
%	https://docs.google.com/spreadsheets/d/e/2PACX-1vReo5eWk6dJPhLLSyOjzEkLDV0jcmT-TpUhvU49oHJ0S6veWHT8HyJVZmaRD_IX6uC9FPhcvgqdY_mW/pubhtml
%
%	Library V2 documentation:
%	https://docs.google.com/spreadsheets/d/e/2PACX-1vQinoUdNJ9lOkU2rXf7XYloEV3dRdZEd-AJRCSSkMoRjaA03AsaVFRaJIMWbD7IIyDRDrkSpkOE6Qp1/pubhtml
%
%	This file was programmatically generated: 10-Sep-2021 10:50:47
%	by script: Update_MotoTrak_Libraries.m
%

serial_codes = [];

switch ver

	case 2.00

		serial_codes.CUR_DEF_VERSION = 200;

		serial_codes.SKETCH_VERIFY = 65;
		serial_codes.GET_SKETCH_VERSION = 90;
		serial_codes.GET_SERIAL_LIB_VER = 91;
		serial_codes.GET_BOOTH_NUMBER = 66;
		serial_codes.DEVICE_ID = 68;

		serial_codes.READ_DEVICE_VAL = 77;
		serial_codes.RESET_COUNTER = 76;
		serial_codes.STREAM_ENABLE = 103;
		serial_codes.SET_STREAM_ORDER = 97;
		serial_codes.RETURN_STREAM_ORDER = 100;
		serial_codes.SET_STREAM_PERIOD = 101;
		serial_codes.RETURN_STREAM_PERIOD = 102;
		serial_codes.SET_EVENT_INPUT = 105;
		serial_codes.RETURN_EVENT_INPUT = 106;
		serial_codes.SET_EVENT_SIZE = 107;
		serial_codes.RETURN_EVENT_SIZE = 108;

		serial_codes.SAVE_1BYTE_EEPROM = 69;
		serial_codes.READ_1BYTE_EEPROM = 70;
		serial_codes.SAVE_2BYTES_EEPROM = 67;
		serial_codes.READ_2BYTES_EEPROM = 73;
		serial_codes.SAVE_4BYTES_EEPROM = 71;
		serial_codes.READ_4BYTES_EEPROM = 72;

		serial_codes.TRIGGER_FEEDER = 87;
		serial_codes.STOP_FEED = 86;
		serial_codes.SET_FEED_TRIG_DUR = 53;
		serial_codes.RETURN_FEED_TRIG_DUR = 52;

		serial_codes.SET_AP_DIST = 110;
		serial_codes.RETURN_AP_DIST = 111;
		serial_codes.RETURN_AP_POS = 112;

		serial_codes.PLAY_TONE = 49;
		serial_codes.STOP_TONE = 50;
		serial_codes.SET_TONE_VOLUME = 54;
		serial_codes.RETURN_TONE_VOLUME = 59;
		serial_codes.SET_TONE_INDEX = 41;
		serial_codes.RETURN_TONE_INDEX = 42;
		serial_codes.SET_TONE_FREQ = 43;
		serial_codes.RETURN_TONE_FREQ = 44;
		serial_codes.SET_TONE_DUR = 45;
		serial_codes.RETURN_TONE_DUR = 46;
		serial_codes.SET_TONE_TYPE = 47;
		serial_codes.RETURN_TONE_TYPE = 48;
		serial_codes.SET_TONE_MON = 37;
		serial_codes.RETURN_TONE_MON = 38;
		serial_codes.SET_TONE_THRESH = 39;
		serial_codes.RETURN_TONE_THRESH = 40;
		serial_codes.RETURN_MAX_TONES = 51;

		serial_codes.SEND_TRIGGER = 88;
		serial_codes.STOP_TRIGGER = 104;
		serial_codes.SET_TRIG_INDEX = 78;
		serial_codes.RETURN_TRIG_INDEX = 79;
		serial_codes.SET_TRIG_DUR = 56;
		serial_codes.RETURN_TRIG_DUR = 55;
		serial_codes.SET_TRIG_TYPE = 80;
		serial_codes.RETURN_TRIG_TYPE = 81;
		serial_codes.SET_TRIG_MON = 82;
		serial_codes.RETURN_TRIG_MON = 83;
		serial_codes.SET_TRIG_THRESH = 84;
		serial_codes.RETURN_TRIG_THRESH = 85;

		serial_codes.SET_CAGE_LIGHTS = 57;
		serial_codes.RETURN_CAGE_LIGHTS = 58;

		serial_codes.CMD_SET_EEPROM_ADDR = 1;
		serial_codes.CMD_WRITE_EEPROM = 2;
		serial_codes.CMD_READ_EEPROM = 3;
		serial_codes.CMD_DEVICE_READING = 4;
		serial_codes.CMD_STREAM_ENABLE = 5;
		serial_codes.CMD_SET_STREAM_ORDER = 6;
		serial_codes.CMD_SET_STREAM_PERIOD = 7;
		serial_codes.CMD_SET_EVENT_INPUT = 8;
		serial_codes.CMD_SET_EVENT_SIZE = 9;
		serial_codes.CMD_SET_FEED_TRIG_DUR = 10;
		serial_codes.CMD_SET_TONE_INDEX = 11;
		serial_codes.CMD_SET_TONE_FREQ = 12;
		serial_codes.CMD_SET_TONE_DUR = 13;
		serial_codes.CMD_SET_TONE_TYPE = 14;
		serial_codes.CMD_SET_TONE_MON = 15;
		serial_codes.CMD_SET_TONE_THRESH = 16;
		serial_codes.CMD_PLAY_TONE = 17;
		serial_codes.CMD_SEND_TRIGGER = 18;
		serial_codes.CMD_SET_TRIG_INDEX = 19;
		serial_codes.CMD_SET_TRIG_DUR = 20;
		serial_codes.CMD_SET_TRIG_TYPE = 21;
		serial_codes.CMD_SET_TRIG_MON = 22;
		serial_codes.CMD_SET_TRIG_THRESH = 23;
		serial_codes.CMD_READ_AP_DIST = 24;
		serial_codes.CMD_SEND_AP_COMM = 25;
		serial_codes.CMD_SET_CAGE_LIGHTS = 26;
		serial_codes.CMD_SET_TONE_VOLUME = 27;

		serial_codes.EEPROM_BOOTH_NUM = 0;

		serial_codes.EEPROM_CAL_BASE_INT = 4;

		serial_codes.EEPROM_CAL_FORCE_INT = 6;

		serial_codes.EEPROM_CAL_TICK_INT = 8;

		serial_codes.EEPROM_LEVER_RANGE = 126;

		serial_codes.EEPROM_SN = 10;

		serial_codes.EEPROM_BOOTH_ID = 14;

		serial_codes.EEPROM_CAL_BASE_FL = 38;

		serial_codes.EEPROM_CAL_SLOPE_FL = 42;


    otherwise

		serial_codes.CUR_DEF_VERSION = 210;

		serial_codes.SKETCH_VERIFY = 65;
		serial_codes.SET_BOOTH_NUMBER = 67;
		serial_codes.GET_SKETCH_VER = 110;
		serial_codes.GET_BOOTH_NUMBER = 111;
		serial_codes.DEVICE_ID = 112;
		serial_codes.GET_SERIAL_LIB_VER = 113;

		serial_codes.READ_1BYTE_EEPROM = 120;
		serial_codes.SAVE_1BYTE_EEPROM = 121;
		serial_codes.READ_2BYTES_EEPROM = 122;
		serial_codes.SAVE_2BYTES_EEPROM = 123;
		serial_codes.READ_4BYTES_EEPROM = 124;
		serial_codes.SAVE_4BYTES_EEPROM = 125;

		serial_codes.STREAM_ENABLE = 130;
		serial_codes.RETURN_STREAM_PERIOD = 131;
		serial_codes.SET_STREAM_PERIOD = 132;
		serial_codes.RETURN_STREAM_ORDER = 133;
		serial_codes.SET_STREAM_ORDER = 134;
		serial_codes.RETURN_EVENT_INPUT = 135;
		serial_codes.SET_EVENT_INPUT = 136;
		serial_codes.RETURN_EVENT_SIZE = 137;
		serial_codes.SET_EVENT_SIZE = 138;
		serial_codes.READ_DEVICE_VAL = 139;
		serial_codes.RESET_COUNTER = 140;

		serial_codes.RETURN_AP_DIST = 150;
		serial_codes.SET_AP_DIST = 151;

		serial_codes.TRIGGER_FEEDER = 160;
		serial_codes.STOP_FEED = 161;
		serial_codes.RETURN_FEED_TRIG_DUR = 162;
		serial_codes.SET_FEED_TRIG_DUR = 163;

		serial_codes.RETURN_CAGE_LIGHTS = 170;
		serial_codes.SET_CAGE_LIGHTS = 171;

		serial_codes.PLAY_TONE = 180;
		serial_codes.STOP_TONE = 181;
		serial_codes.RETURN_TONE_INDEX = 182;
		serial_codes.SET_TONE_INDEX = 183;
		serial_codes.RETURN_TONE_FREQ = 184;
		serial_codes.SET_TONE_FREQ = 185;
		serial_codes.RETURN_TONE_DUR = 186;
		serial_codes.SET_TONE_DUR = 187;
		serial_codes.RETURN_TONE_TYPE = 188;
		serial_codes.SET_TONE_TYPE = 189;
		serial_codes.RETURN_TONE_MON = 190;
		serial_codes.SET_TONE_MON = 191;
		serial_codes.RETURN_TONE_THRESH = 192;
		serial_codes.SET_TONE_THRESH = 193;
		serial_codes.RETURN_MAX_TONES = 194;

		serial_codes.SEND_TRIGGER = 200;
		serial_codes.STOP_TRIGGER = 201;
		serial_codes.RETURN_TRIG_INDEX = 202;
		serial_codes.SET_TRIG_INDEX = 203;
		serial_codes.RETURN_TRIG_DUR = 204;
		serial_codes.SET_TRIG_DUR = 205;
		serial_codes.RETURN_TRIG_TYPE = 206;
		serial_codes.SET_TRIG_TYPE = 207;
		serial_codes.RETURN_TRIG_MON = 208;
		serial_codes.SET_TRIG_MON = 209;
		serial_codes.RETURN_TRIG_THRESH = 210;
		serial_codes.SET_TRIG_THRESH = 211;

		serial_codes.RETURN_DAC_STATUS = 220;
		serial_codes.RETURN_DAC_MODE = 221;
		serial_codes.SET_DAC_MODE = 222;

		serial_codes.VIB_TOGGLE = 33;
		serial_codes.RETURN_VIB_DUR = 34;
		serial_codes.SET_VIB_DUR = 35;
		serial_codes.RETURN_VIB_IPI = 36;
		serial_codes.SET_VIB_IPI = 37;
		serial_codes.RETURN_VIB_N = 38;
		serial_codes.SET_VIB_N = 39;
		serial_codes.RETURN_VIB_GAP_START = 40;
		serial_codes.SET_VIB_GAP_START = 41;
		serial_codes.RETURN_VIB_GAP_STOP = 42;
		serial_codes.SET_VIB_GAP_STOP = 43;
		serial_codes.START_VIB = 44;
		serial_codes.STOP_VIB = 45;
		serial_codes.VIB_MASK_ENABLE = 46;
		serial_codes.RETURN_VIB_TONE_FREQ = 47;
		serial_codes.SET_VIB_TONE_FREQ = 58;
		serial_codes.RETURN_VIB_TONE_DUR = 59;
		serial_codes.SET_VIB_TONE_DUR = 60;
		serial_codes.RETURN_VIB_TASK_MODE = 61;
		serial_codes.SET_VIB_TASK_MODE = 62;
		serial_codes.RETURN_VIB_INDEX = 63;
		serial_codes.SET_VIB_INDEX = 64;

		serial_codes.BWC_GET_BOOTH_NUMBER = 66;
		serial_codes.BWC_GET_SKETCH_VER = 90;
		serial_codes.BWC_SET_AP_DIST = 48;
		serial_codes.BWC_RETURN_FEED_TRIG_DUR = 52;
		serial_codes.BWC_SET_FEED_TRIG_DUR = 53;
		serial_codes.BWC_TRIGGER_FEEDER = 87;
		serial_codes.BWC_FEED = 51;
		serial_codes.BWC_SEND_TRIGGER = 88;
		serial_codes.BWC_STIMULATE = 54;
		serial_codes.BWC_RETURN_TRIG_DUR = 55;
		serial_codes.BWC_SET_TRIG_DUR = 56;
		serial_codes.BWC_SET_CAGE_LIGHTS = 57;
		serial_codes.BWC_DEVICE_ID = 68;
		serial_codes.BWC_KNOB_TOGGLE = 69;
		serial_codes.BWC_READ_DEVICE_VAL = 77;
		serial_codes.BWC_GET_BASELINE = 78;
		serial_codes.BWC_SET_BASELINE = 79;
		serial_codes.BWC_GET_CAL_GRAMS = 80;
		serial_codes.BWC_SET_CAL_GRAMS = 81;
		serial_codes.BWC_GET_CAL_TICKS = 82;
		serial_codes.BWC_SET_CAL_TICKS = 83;
		serial_codes.BWC_SET_STREAM_PERIOD = 101;
		serial_codes.BWC_RETURN_STREAM_PERIOD = 102;
		serial_codes.BWC_STREAM_ENABLE = 103;
		serial_codes.BWC_PLAY_HIT_SOUND = 74;
		serial_codes.BWC_PLAY_1000HZ_TONE = 49;
		serial_codes.BWC_PLAY_1100HZ_TONE = 50;

		serial_codes.CMD_SET_EEPROM_ADDR = 1;
		serial_codes.CMD_WRITE_EEPROM = 2;
		serial_codes.CMD_READ_EEPROM = 3;
		serial_codes.CMD_DEVICE_READING = 4;
		serial_codes.CMD_STREAM_ENABLE = 5;
		serial_codes.CMD_SET_STREAM_ORDER = 6;
		serial_codes.CMD_SET_STREAM_PERIOD = 7;
		serial_codes.CMD_SET_EVENT_INPUT = 8;
		serial_codes.CMD_SET_EVENT_SIZE = 9;
		serial_codes.CMD_SET_FEED_TRIG_DUR = 10;
		serial_codes.CMD_SET_TONE_INDEX = 11;
		serial_codes.CMD_SET_TONE_FREQ = 12;
		serial_codes.CMD_SET_TONE_DUR = 13;
		serial_codes.CMD_SET_TONE_TYPE = 14;
		serial_codes.CMD_SET_TONE_MON = 15;
		serial_codes.CMD_SET_TONE_THRESH = 16;
		serial_codes.CMD_PLAY_TONE = 17;
		serial_codes.CMD_SEND_TRIGGER = 18;
		serial_codes.CMD_SET_TRIG_INDEX = 19;
		serial_codes.CMD_SET_TRIG_DUR = 20;
		serial_codes.CMD_SET_TRIG_TYPE = 21;
		serial_codes.CMD_SET_TRIG_MON = 22;
		serial_codes.CMD_SET_TRIG_THRESH = 23;
		serial_codes.CMD_READ_AP_DIST = 24;
		serial_codes.CMD_SEND_AP_COMM = 25;
		serial_codes.CMD_SET_CAGE_LIGHTS = 26;
		serial_codes.CMD_RETURN_DAC_MODE = 27;
		serial_codes.CMD_SET_DAC_MODE = 28;
		serial_codes.CMD_SET_DAC_INDEX = 29;
		serial_codes.CMD_BWC_MODE_2 = 30;
		serial_codes.CMD_BWC_MODE_3 = 31;
		serial_codes.CMD_BWC_MODE_7 = 32;
		serial_codes.CMD_BWC_MODE_8 = 33;
		serial_codes.CMD_BWC_MODE_13 = 34;
		serial_codes.CMD_BWC_MODE_16 = 35;
		serial_codes.CMD_BWC_MODE_17 = 36;
		serial_codes.CMD_BWC_MODE_104 = 37;
		serial_codes.CMD_BWC_MODE_105 = 38;
		serial_codes.CMD_BWC_MODE_106 = 39;
		serial_codes.CMD_BWC_MODE_107 = 40;
		serial_codes.CMD_BWC_IGNORE = 41;
		serial_codes.CMD_SET_VIB_DUR = 42;
		serial_codes.CMD_SET_VIB_IPI = 43;
		serial_codes.CMD_SET_VIB_N = 44;
		serial_codes.CMD_SET_VIB_GAP_START = 45;
		serial_codes.CMD_SET_VIB_GAP_STOP = 46;
		serial_codes.CMD_VIB_MASK_ENABLE = 47;
		serial_codes.CMD_SET_VIB_TONE_FREQ = 48;
		serial_codes.CMD_SET_VIB_TONE_DUR = 49;
		serial_codes.CMD_SET_VIB_TASK_MODE = 50;
		serial_codes.CMD_SET_VIB_INDEX = 51;

		serial_codes.EEPROM_BOOTH_NUM = 0;

		serial_codes.EEPROM_CAL_BASE_INT = 4;

		serial_codes.EEPROM_CAL_FORCE_INT = 6;

		serial_codes.EEPROM_CAL_TICK_INT = 8;

		serial_codes.EEPROM_LEVER_RANGE = 126;

		serial_codes.EEPROM_SN = 10;

		serial_codes.EEPROM_BOOTH_ID = 14;

		serial_codes.EEPROM_CAL_BASE_FL = 38;

		serial_codes.EEPROM_CAL_SLOPE_FL = 42;

end
