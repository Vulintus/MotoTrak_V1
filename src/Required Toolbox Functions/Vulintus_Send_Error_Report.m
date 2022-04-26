function Vulintus_Send_Error_Report(recipient,subject,msg)

%
%Vulintus_Send_Error_Report.m - Vulintus, Inc.
%
%   Vulintus_Send_Error_Report sends an error report ("msg") by email to 
%   the specified recipient ("target") through the Vulintus dummy 
%   error-reporting account.
%
%   The funtion must be compiled for deployment. Compile using the
%   following command in the command line:
%   
%       mcc -e -v Vulintus_Send_Error_Report.m
%   
%   UPDATE LOG:
%   02/21/2017 - Drew Sloan - Added enabling of a STARTTLS command.
%

try                                                                         %Attempt to send an email with the error information.
    setpref('Internet','E_mail','error.report@vulintus.com');               %Set the default email sender to "error.report@vulintus.com".
    setpref('Internet','SMTP_Server','smtp.gmail.com');                     %Set the SMTP server to Gmail.
    setpref('Internet','SMTP_Username','error.report@vulintus.com');        %Set the SMTP username.
    setpref('Internet','SMTP_Password','vulintus');                         %Set the password for the error reporting account.
    props = java.lang.System.getProperties;                                 %Grab the javascript email properties.
    props.setProperty('mail.smtp.auth','true');                             %Set the email properties to enable gmail logins.
    props.setProperty('mail.smtp.starttls.enable','true');                  %Enable the STARTTLS command.
    props.setProperty('mail.smtp.socketFactory.class', ...
                      'javax.getprfenet.ssl.SSLSocketFactory');             %Create an SSL socket.                  
    props.setProperty('mail.smtp.socketFactory.port','465');                %Set the email socket to a secure port.
    sendmail(recipient,subject,msg);                                        %Email the new and old calibration values to the specified users.
catch err                                                                   %Otherwise...
    warning('%s - %s',err.identifier,err.message);                          %Show the error message as a warning.                                                                  
end