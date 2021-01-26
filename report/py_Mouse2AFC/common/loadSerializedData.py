import numpy as np
from .hlp_deserialize import hlp_deserialize

def loadSerializedData(mapped_file, data_start):
    data_end = data_start + 4
    data_length = np.frombuffer(mapped_file[data_start:data_end],
                                dtype=np.uint32)[0]
    # print("Custom data length: " + str(data_length))
    data_start = data_end
    data_end = data_start + data_length
    # print("Start:", data_start, " - End:", data_end)
    serialized_data = mapped_file[data_start:data_end]
    data = hlp_deserialize(serialized_data)
    next_data_start = data_end
    return next_data_start, data

