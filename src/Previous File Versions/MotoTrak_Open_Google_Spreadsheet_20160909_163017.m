function MotoTrak_Open_Google_Spreadsheet(~,~,url)

if strncmpi(url,'https://docs.google.com/spreadsheet/pub',39)               %If the URL is in the old-style format...
    i = strfind(url,'key=') + 4;                                            %Find the start of the spreadsheet key.
    key = url(i:i+43);                                                      %Grab the 44-character spreadsheet key.
else                                                                        %Otherwise...
    i = strfind(url,'/d/') + 3;                                             %Find the start of the spreadsheet key.
    key = url(i:i+43);                                                      %Grab the 44-character spreadsheet key.
end
str = sprintf('https://docs.google.com/spreadsheets/d/%s/',key);            %Create the Google spreadsheet general URL from the spreadsheet key.
web(str,'-browser');                                                        %Open the Google spreadsheet in the default system browser.