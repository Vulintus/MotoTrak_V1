function [d] = daycode(varargin)

%
%daycode.m - OU Neural Engineering Lab, 2007
%
%   daycode.m returns the day code for today or any date inputted.  The day
%   code is simply the number of the day in a year, so between 1-365 unless
%   the year is a leap year, in which case it's between 1-366.
%
%   daycode returns the day code for today.
%
%   daycode(date) returns the day code for the input date, in which date is
%   in date string, date vector, or serial date number format.
%
%
%   NELtoSPK(...,'Property1',PropertyValue1,...) sets the values of any of the
%   following optional thresholding properties:
%
%   Last updated April 16, 2009, by Drew Sloan.

if isempty(varargin)            %If the user hasn't specified a date...
    temp = datevec(now);        %Find the daycode for today and convert that to a date vector.
elseif length(varargin) == 1    %If the user has specified a date...
    temp = cell2mat(varargin);  %Convert the cell input to a string or number.
    if ischar(temp) || length(temp) == 1  %If it's a date string or serial date number...
        temp = datevec(temp);           %Convert the date to a date vector.
    end
    if ~isequal(size(temp),[1 6])   %If the date vector is not properly formated...
        %Return an error message and cancel.
        error('- Input is not a proper date string, date vector, or serial date number.');
    end
else    %If the input argument is longer than one, then there's too many inputs.
    error('- Too many input arguments.  Input one date string, date vector, or serial date number.');
end


year = temp(1);     %Pull the year out of the date vector.
month = temp(2);    %Pull out the month.
day = temp(3);      %Pull out the day.

if year/4 == fix(year/4);   %If the year is a leap year, February has 29 days.
    numDays = [31 29 31 30 31 30 31 31 30 31 30 31];
else                        %Otherwise, February has 28 days.
	numDays = [31 28 31 30 31 30 31 31 30 31 30 31];
end

%The daycode is the day of the specified month plus all the days in the
%preceding months.
temp = sum(numDays(1:(month-1)));   %Days in the preceding months...
d = temp + day;                     %...plus day of the specified month.