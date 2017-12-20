%%
% TODO

% Copyright (c) 2017, ETH Zurich, Automatic Control Laboratory 
%                    Damian Frick <falcopt@damianfrick.com>
% 
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
% 
% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.
% 
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.
%
function [code, define] = generateTimer(varargin)
    indentTypes = {'generic', 'code'};
    p = inputParser;
    p.addParameter('indent', '    ', @(x)(ischar(x) || (isstruct(x) && isfield(x, 'generic') && all(cellfun(@(y)(~isfield(x, y) || ischar(x.(y))), indentTypes)))));
    p.addParameter('header', true, @islogical);
    p.parse(varargin{:});
    options = p.Results;
    
    %% Processing options
    % Indentation
    if ~isstruct(options.indent)
        indent = options.indent;
        options.indent = struct();
        for i=1:length(indentTypes)
            options.indent.(indentTypes{i}) = indent;
        end
    end
    for i=1:length(indentTypes)
        if ~isfield(options.indent, indentTypes{i})
            options.indent.(indentTypes{i}) = options.indent.generic;
        end
        options.indent.(indentTypes{i}) = options.indent.(indentTypes{i})(:)'; % Make sure is row vector
    end
    
    defines.win = sprintf(['#include <windows.h>' '\n' '\n' ...
                           options.indent.code options.indent.generic 'typedef struct {' '\n' ...
                           options.indent.code options.indent.generic options.indent.generic 'LARGE_INTEGER start;' '\n' ...
                           options.indent.code options.indent.generic options.indent.generic 'LARGE_INTEGER stop;' '\n'...
                           options.indent.code options.indent.generic options.indent.generic 'LARGE_INTEGER freq;' '\n' ...
                           options.indent.code options.indent.generic '} timer;']);
    defines.mac = sprintf(['/* Reference: https://developer.apple.com/library/mac/qa/qa1398/_index.html */' '\n' ...
                           options.indent.code options.indent.generic '#include <mach/mach_time.h>' '\n' '\n' ...
                           options.indent.code options.indent.generic '#define TIMER_NANOTOSEC (1.0/1e9)' '\n' '\n' ...
                           options.indent.code options.indent.generic 'typedef struct {' '\n' ...
                           options.indent.code options.indent.generic options.indent.generic 'uint64_t start;' '\n' ...
                           options.indent.code options.indent.generic options.indent.generic 'uint64_t stop;' '\n'...
                           options.indent.code options.indent.generic options.indent.generic 'double toSeconds;' '\n' ...
                           options.indent.code options.indent.generic '} timer;']);
    defines.unix = sprintf(['#include <time.h>' '\n' ...
                            options.indent.code options.indent.generic '#include <sys/time.h>' '\n' '\n' ...
                            options.indent.code options.indent.generic '#define TIMER_SECTONANO (1e9)' '\n' ... 
                            options.indent.code options.indent.generic '#define TIMER_NANOTOSEC (1.0/TIMER_SECTONANO)' '\n' '\n' ...
                            options.indent.code options.indent.generic 'typedef struct {' '\n' ...
                            options.indent.code options.indent.generic options.indent.generic 'struct timespec start;' '\n' ...
                            options.indent.code options.indent.generic options.indent.generic 'struct timespec stop;' '\n' ...
                            options.indent.code options.indent.generic '} timer;']);
                        
	codes.win = sprintf(['double timer_getTime(timer* t) {' '\n' ...
                         options.indent.code options.indent.generic options.indent.generic 'return (t->stop.QuadPart - t->start.QuadPart) / (double)(t->freq.QuadPart); }' '\n' ...
                         options.indent.code options.indent.generic 'void timer_init(timer* t) { /* Initialize frequency */' '\n' ...
                         options.indent.code options.indent.generic options.indent.generic 'QueryPerformanceFrequency(&(t->freq)); }' '\n' ...
                         options.indent.code options.indent.generic 'void timer_start(timer* t) {' '\n' ...
                         options.indent.code options.indent.generic options.indent.generic 'QueryPerformanceCounter(&(t->start)); }' '\n'...
                         options.indent.code options.indent.generic 'double timer_stop(timer* t) {' '\n' ...
                         options.indent.code options.indent.generic options.indent.generic 'QueryPerformanceCounter(&(t->stop));' '\n' ...
                         options.indent.code options.indent.generic options.indent.generic 'return timer_getTime(t);' '\n' ...
                         options.indent.code options.indent.generic '};']);
    codes.mac = sprintf(['double timer_getTime(timer* t) {' '\n' ...
                         options.indent.code options.indent.generic options.indent.generic 'return (double)(t->stop-t->start) * t->toSeconds; }' '\n' ...
                         options.indent.code options.indent.generic 'void timer_init(timer* t) {' '\n' ...
                         options.indent.code options.indent.generic options.indent.generic 'mach_timebase_info_data_t info;' '\n' ...
                         options.indent.code options.indent.generic options.indent.generic '(void) mach_timebase_info(&info);  /* Get time base */' '\n' ...
                         options.indent.code options.indent.generic options.indent.generic 't->toSeconds = TIMER_NANOTOSEC * (double)(info.numer / info.denom);' '\n' ...
                         options.indent.code options.indent.generic '};' '\n' ...
                         options.indent.code options.indent.generic 'void timer_start(timer* t) {' '\n' ...
                         options.indent.code options.indent.generic options.indent.generic 't->start = mach_absolute_time(); }' '\n' ...
                         options.indent.code options.indent.generic 'double timer_stop(timer* t) {' '\n' ...
                         options.indent.code options.indent.generic options.indent.generic 't->stop = mach_absolute_time();' '\n' ...
                         options.indent.code options.indent.generic options.indent.generic 'return timer_getTime(t);' '\n' ...
                         options.indent.code options.indent.generic '};']);
    codes.unix = sprintf(['double timer_getTime(timer* t) {' '\n' ...
                          options.indent.code options.indent.generic options.indent.generic 'if(t->stop.tv_nsec < t->start.tv_nsec) { /* Overflow occurred */' '\n' ...
                          options.indent.code options.indent.generic options.indent.generic options.indent.generic 'return (double)(t->stop.tv_sec - t->start.tv_sec)-1.0 + ((double)(t->stop.tv_nsec - t->start.tv_nsec) + TIMER_SECTONANO)*TIMER_NANOTOSEC; }' '\n' ...
                          options.indent.code options.indent.generic options.indent.generic 'return (double)(t->stop.tv_sec - t->start.tv_sec) + ((double)(t->stop.tv_nsec - t->start.tv_nsec))*TIMER_NANOTOSEC;' '\n' ...
                          options.indent.code options.indent.generic '};' '\n' ...
                          options.indent.code options.indent.generic 'void timer_init(timer* t) { }' '\n' ...
                          options.indent.code options.indent.generic 'void timer_start(timer* t) {' '\n' ...
                          options.indent.code options.indent.generic options.indent.generic 'clock_gettime(CLOCK_MONOTONIC, &(t->start)); }' '\n' ...
                          options.indent.code options.indent.generic 'double timer_stop(timer* t) {' '\n' ...
                          options.indent.code options.indent.generic options.indent.generic 'clock_gettime(CLOCK_MONOTONIC, &(t->stop));' '\n' ...
                          options.indent.code options.indent.generic options.indent.generic 'return timer_getTime(t);' '\n' ...
                          options.indent.code options.indent.generic '};']);
    
    if options.header
        define = sprintf([options.indent.code '#if defined (_WIN32) || defined (_WIN64) /* Windows */\n' ...
                          options.indent.code options.indent.generic defines.win '\n' ...
                          options.indent.code '#elif defined (__APPLE__) && defined (__MACH__) /* Mac */' '\n' ...
                          options.indent.code options.indent.generic defines.max '\n' ...
                          options.indent.code '#else /* Unix */' '\n' ...
                          options.indent.code options.indent.generic defines.unix '\n' ...
                          options.indent.code '#endif' '\n' '\n' ...
                          options.indent.code 'double timer_getTime(timer* t);' '\n' ...
                          options.indent.code 'void timer_init(timer* t);' '\n' ...
                          options.indent.code 'void timer_start(timer* t);' '\n' ...
                          options.indent.code 'double timer_stop(timer* t);']);

        code = sprintf(...
               [options.indent.code '#if defined (_WIN32) || defined (_WIN64) /* Windows */' '\n' ...
                options.indent.code options.indent.generic codes.win '\n' ...
                options.indent.code '#elif defined (__APPLE__) && defined (__MACH__) /* Mac */' '\n' ...
                options.indent.code options.indent.generic codes.mac '\n' ...
                options.indent.code '#else /* Unix */' '\n' ...
                options.indent.code options.indent.generic codes.unix '\n' ...
                options.indent.code '#endif']);
    else
        code = sprintf(...
               [options.indent.code '#if defined (_WIN32) || defined (_WIN64) /* Windows */' '\n' ...
                options.indent.code options.indent.generic defines.win '\n' '\n' ...
                options.indent.code options.indent.generic codes.win '\n' ...
                options.indent.code '#elif defined (__APPLE__) && defined (__MACH__) /* Mac */' '\n' ...
                options.indent.code options.indent.generic defines.mac '\n' '\n' ...
                options.indent.code options.indent.generic codes.mac '\n' ...
                options.indent.code '#else /* Unix */' '\n' ...
                options.indent.code options.indent.generic defines.unix '\n' '\n' ...
                options.indent.code options.indent.generic codes.unix '\n' ...
                options.indent.code '#endif']);
        define = '';
    end

end