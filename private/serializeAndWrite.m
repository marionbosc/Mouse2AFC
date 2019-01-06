function next_data_start = serializeAndWrite(mapped_file, data_start, data)
    serialized_data = hlp_serialize(data);
    data_size = size(serialized_data);
    data_size = data_size(1);
    % disp("Serialized data size: " + string(data_size).join(" "));
    serialized_data_size = typecast(uint32(data_size), 'uint8');
    data_end = data_start + 4 -1;
    mapped_file.Data(data_start:data_end) = serialized_data_size;
    data_start = data_end + 1; data_end = data_start + data_size - 1;
    mapped_file.Data(data_start:data_end) = serialized_data;
    next_data_start = data_end + 1;
end
