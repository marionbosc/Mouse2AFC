function [next_data_start, data] = loadSerializedData(mapped_file, data_start)
    data_end = data_start + 4 - 1;
    data_length = typecast(mapped_file.Data(data_start:data_end),'uint32');
    % disp("Custom data length: " + string(data_length));
    data_start = data_end + 1; data_end = data_start + data_length - 1;
    serialized_data = mapped_file.Data(data_start:data_end);
    data = hlp_deserialize(serialized_data);
    next_data_start = data_end + 1;
end
