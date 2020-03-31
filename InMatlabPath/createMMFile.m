function m = createMMFile(fdir, fname, fsize)
% Opens or creates a memory mapped file with fname in fdir with size of
% fsize.
fullpath = fullfile(fdir, fname);

% Create the communications file if it is not already there.
if ~exist(fullpath, 'file')
    [f, msg] = fopen(fullpath, 'wb');
    if f ~= -1
        fwrite(f, zeros(1,fsize), 'uint8');
        fclose(f);
    else
        error('MATLAB:createMMFile', ...
              'Cannot open file "%s": %s.', fullpath, msg);
    end
end

% Memory map the file.
m = memmapfile(fullpath, 'Writable', true, 'Format', 'uint8');

end
