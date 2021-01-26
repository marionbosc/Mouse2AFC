import numpy as np
from scipy.sparse import bsr_matrix
from .attrdict import AttrDict

def hlp_deserialize(m):
# Convert a MATLAB hlp_serilize() serialized byte vector into a
# corresponding python (mostly numpy) data structure.
# Usage:
#   Data = hlp_deserialize(Bytes)
#
# In:
#   Bytes : a representation of the original data as a byte stream
#
# Out:
#   Converted MATLAB data structure
#
# See also:
#   hlp_serialize
#   https://www.mathworks.com/matlabcentral/fileexchange/34564-fast-serialize-deserialize?focused=5215237&tab=function
#
# Examples:
#   bytes = hlp_serialize(mydata);
#   ... e.g. transfer the 'bytes' array over the network ...
#   mydata = hlp_deserialize(bytes);
#
#                                MATLAB version copyright:
#                                Christian Kothe, Swartz Center for Computational Neuroscience, UCSD
#                                2010-04-02
#
#                                adapted from deserialize.m
#                                (C) 2010 Tim Hutt
  # wrap dispatcher
  #return deserialize_value(np.uint8(m),0)
  return deserialize_value(np.frombuffer(m, dtype=np.uint8),0)[0]

# dispatch
#function [v,pos] = deserialize_value(m,pos)
_dispatch_string = np.array([0,200])
# _dispatch_struct = np.array([128])
_dispatch_cell = np.array([33,34,35,36,37,38,39])
_dispatch_scalar = np.array([1,2,3,4,5,6,7,8,9,10])
# _dispatch_logical = np.array([133])
_dispatch_handle = np.array([151,152,153])
_dispatch_numeric_simple = np.array([17,18,19,20,21,22,23,24,25,26])
# _dispatch_sparse = np.array([130])
# _dispatch_complex = np.array([131])
# _dispatch_char = np.array([132])
# _dispatch_obj = np.array([134])

def deserialize_value(m,pos):
  m_pos = m[pos]
  # print("Pos:", pos, "m_pos:", m_pos)
  if m_pos in _dispatch_string:
    v, pos = deserialize_string(m,pos)
  elif m_pos == 128:
    v, pos = deserialize_struct(m,pos)
  elif m_pos in _dispatch_cell:
    v, pos = deserialize_cell(m,pos)
  elif m_pos in _dispatch_scalar:
    v, pos = deserialize_scalar(m,pos)
  elif m_pos == 133:
    v, pos = deserialize_logical(m,pos)
  elif m_pos in _dispatch_handle:
    v, pos = deserialize_handle(m,pos)
  elif m_pos in _dispatch_numeric_simple:
    v, pos = deserialize_numeric_simple(m,pos)
  elif m_pos == 130:
    v, pos = deserialize_sparse(m,pos)
  elif m_pos == 131:
    v, pos = deserialize_complex(m,pos)
  elif m_pos == 132:
    v, pos = deserialize_char(m,pos)
  elif m_pos == 134:
    v, pos = deserialize_object(m,pos)
  else:
    raise RuntimeError('Unknown class')
  return v, pos

# individual scalar
_scalar_dtypes = (np.double, np.single, np.int8, np.uint8, np.int16, np.uint16,
                  np.int32, np.uint32, np.int64, np.uint64)
_scalar_sizes = (8,4,1,1,2,2,4,4,8,8)
def deserialize_scalar(m, pos):
  #classes = ['double','single','int8','uint8','int16','uint16','int32','uint32','int64','uint64'];
  #sizes = [8,4,1,1,2,2,4,4,8,8]
  idx = m[pos]-1
  sz = _scalar_sizes[idx]
  # Data.
  # v = typecast(m(pos+1:pos+sz),classes{m(pos)});
  pos += 1
  v = np.frombuffer(m[pos:pos+sz], dtype=_scalar_dtypes[idx])
  pos = pos + sz
  return v, pos

_empty_str = np.array([], dtype="S1")
# standard string
#function [v,pos] = deserialize_string(m,pos)
def deserialize_string(m, pos):
  if m[pos] == 0:
    # horizontal string: tag
    pos = pos + 1
    # length (uint32)
    # nbytes = double(typecast(m(pos:pos+3),'uint32'))
    nbytes = np.frombuffer(m[pos:pos+4], dtype=np.uint32)[0]
    pos = pos + 4
    # data (chars)
    #v = char(m(pos:pos+nbytes-1))'
    v = np.frombuffer(m[pos:pos+nbytes], dtype=np.uint8).view('S1').T.squeeze()
    # print("str:", v.tostring().decode())
    pos = pos + nbytes
  else:
    # proper empty string: tag
    #v, pos = deal('',pos+1)
    v, pos = _empty_str, pos + 1
  return v, pos



# general char array
#function [v,pos] = deserialize_char(m,pos)
def deserialize_char(m, pos):
  pos = pos + 1
  # Number of dims
  #ndms = double(m(pos));
  ndms = m[pos]
  pos = pos + 1
  # Dimensions
  #dms = double(typecast(m(pos:pos+ndms*4-1),'uint32')');
  dms = np.frombuffer(m[pos:pos+ndms*4], dtype=np.uint32).T
  pos = pos + ndms*4
  #nbytes = prod(dms);
  nbytes = np.prod(dms, dtype=np.intp)
  # Data.
  # v = char(m(pos:pos+nbytes-1));
  v = np.frombuffer(m[pos:pos+nbytes], dtype=np.uint8).view('S1')
  pos = pos + nbytes
  # v = np.reshape(v,(dms 1 1));
  v = np.reshape(v, dms, order='F').squeeze()
  return v, pos

# general logical array
#function [v,pos] = deserialize_logical(m,pos)
def deserialize_logical(m, pos):
  pos = pos + 1
  # Number of dims
  #ndms = double(m(pos));
  ndms = m[pos]
  pos = pos + 1
  # Dimensions
  #dms = double(typecast(m(pos:pos+ndms*4-1),'uint32')');
  dms = np.frombuffer(m[pos:pos+ndms*4], dtype=np.uint32).T
  pos = pos + ndms*4
  nbytes = np.prod(dms, dtype=np.intp)
  # Data.
  #v = logical(m(pos:pos+nbytes-1));
  v = np.frombuffer(m[pos:pos+nbytes], dtype=np.bool_)
  pos = pos + nbytes
  #v = reshape(v,[dms 1 1]);
  v = np.reshape(v, dms, order='F').squeeze()
  return v, pos

# simple numerical matrix
#function [v,pos] = deserialize_numeric_simple(m,pos)
def deserialize_numeric_simple(m,pos):
  # classes = ['double','single','int8','uint8','int16','uint16','int32','uint32','int64','uint64']
  # sizes = [8,4,1,1,2,2,4,4,8,8]
  #cls = classes{m(pos)-16};
  #sz = sizes(m(pos)-16);
  idx = m[pos]-17
  sz = _scalar_sizes[idx]
  pos = pos + 1
  # Number of dims
  #ndms = double(m(pos));
  ndms = m[pos]
  pos = pos + 1
  # Dimensions
  #dms = double(typecast(m(pos:pos+ndms*4-1),'uint32')');
  dms = np.frombuffer(m[pos:pos+ndms*4], dtype=np.uint32).T
  pos = pos + ndms*4
  nbytes = int(np.prod(dms) * sz) # TODO: Use size_t rather than 64
  # Data.
  #v = typecast(m(pos:pos+nbytes-1),cls);
  v = np.frombuffer(m[pos:pos+nbytes], dtype=_scalar_dtypes[idx])
  pos = pos + nbytes
  #v = reshape(v,[dms 1 1]);
  v = np.reshape(v, dms, order='F').squeeze()
  return v, pos

# complex matrix
#function [v,pos] = deserialize_complex(m,pos)
def deserialize_complex(m, pos):
  pos = pos + 1
  re, pos = deserialize_numeric_simple(m,pos)
  im, pos = deserialize_numeric_simple(m,pos)
  #v = np.complex(re,im);
  v = re + 1j*im #TODO: This might not be memory friendly, will check later
  return v, pos

# sparse matrix
#function [v,pos] = deserialize_sparse(m,pos)
def deserialize_sparse(m, pos):
  pos = pos + 1
  # matrix dims
  #u = double(typecast(m(pos:pos+7),'uint64'));
  u = np.frombuffer(m[pos:pos+8], dtype=np.uint64).squeeze()
  pos = pos + 8
  #v = double(typecast(m(pos:pos+7),'uint64'));
  v = np.frombuffer(m[pos:pos+8], dtype=np.uint64).squeeze()
  pos = pos + 8
  # index vectors
  i, pos = deserialize_numeric_simple(m,pos)
  j, pos = deserialize_numeric_simple(m,pos)
  if m[pos]:
    # real
    pos = pos+1
    s, pos = deserialize_numeric_simple(m,pos)
  else:
    # complex
    pos = pos + 1
    re, pos = deserialize_numeric_simple(m,pos)
    im, pos = deserialize_numeric_simple(m,pos)
    #s = complex(re,im);
    s = re + 1j*im #TODO: Also check if it's quick enough
  # MATLAB indices are 1-based, subtract 1 to be zero-based index
  i = i.astype(np.intp, copy=False).squeeze() - 1
  j = j.astype(np.intp, copy=False).squeeze() - 1
  s = s.squeeze()
  #v = sparse(i,j,s,u,v);
  v = bsr_matrix((s, (i,j)),shape=(u,v))
  return v, pos

_empty_arr = np.empty((0))
# struct array
#function [v,pos] = deserialize_struct(m,pos)
def deserialize_struct(m, pos):
  pos = pos + 1
  # Number of field names.
  #nfields = double(typecast(m(pos:pos+3),'uint32'))
  nfields = np.frombuffer(m[pos:pos+4], dtype=np.uint32).squeeze()
  pos = pos + 4
  # Field name lengths
  #fnLengths = double(typecast(m(pos:pos+nfields*4-1),'uint32'))
  fnLengths = np.frombuffer(m[pos:pos+nfields*4], dtype=np.uint32).squeeze()
  pos = np.intp(pos + nfields*4)
  # Field name char data
  #fnChars = char(m(pos:pos+sum(fnLengths)-1)).'
  fnChars = np.frombuffer(m[pos:np.intp(pos+np.sum(fnLengths))],
                          dtype=np.uint8).view("S1").T
  pos = np.intp(pos + len(fnChars))
  # Number of dims
  #ndms = double(typecast(m(pos:pos+3),'uint32'))
  ndms = np.frombuffer(m[pos:pos+4], dtype=np.uint32).squeeze()
  pos = pos + 4
  # Dimensions
  #dms = typecast(m(pos:pos+ndms*4-1),'uint32')'
  dms = np.frombuffer(m[pos:pos+ndms*4], dtype=np.uint32).squeeze()
  pos = pos + ndms*4
  # Field names.
  fieldNames = [None]*len(np.atleast_1d(fnLengths))#cell(len(fnLengths),1)
  # splits = [0; np.cumsum(double(fnLengths))]
  splits = np.cumsum(fnLengths).astype(np.intp, copy=False)
  #for k=1:length(splits)-1
  fieldNames[0] = fnChars[0:splits[0]].tostring().decode("utf-8")
  for k in range(len(splits)-1):
    #fieldNames{k} = fnChars(splits(k)+1:splits(k+1)); enda
    fieldNames[k+1] = fnChars[splits[k]:splits[k+1]].tostring().decode("utf-8")

  #print("Fields names:", fieldNames, "Pos:", pos, "Dms:", dms, f"m[pos]: {m[pos]}")
  # Content.
  # v = reshape(struct(),[dms 1 1]);
  v = AttrDict(zip(fieldNames, [_empty_arr]*len(fieldNames)))
  if m[pos]:
    # using struct2cell
    pos = pos + 1
    contents, pos = deserialize_cell(m,pos)
    if contents.size:
      # for i in range(contents.shape[0]):
      #  print("Content", i, "=", contents[i].squeeze(axis=0))
      # TODO: Use structured arrays
      for i in range(contents.shape[0]):
        val = contents[i]
        if not np.isscalar(val):
          val = val[0]
        if isinstance(val, np.ndarray) and val.dtype == np.object:
          # TODO: Move this part inside desarilize_cell()
          #print("Setting:", val[0].dtype, "=", val.shape, " - ", val)
          val = np.array(val.tolist(), val[0].dtype, copy=False)#np.array(val, dtype=val[0].dtype, copy=False)
        v[fieldNames[i]] = val
        #print("Assigned", fieldNames[i], "- To:",
        #      val.dtype if isinstance(val, np.ndarray) else type(val), " = ", val)
      # print("V:", v)
  else:
    # using per-field cell arrays
    pos = pos + 1
    #for ff = 1:nfields
    for ff in range(nfields):
      contents, pos = deserialize_cell(m,pos)
      # [v.(fieldNames{ff})] = deal(contents{:});
  return v, pos

# cell array
#function [v,pos] = deserialize_cell(m,pos)
def deserialize_cell(m,pos):
  kind = m[pos]
  #print("Kind:", kind, "Pos:", pos)
  pos = pos + 1
  if kind == 33: # arbitrary/heterogenous cell array
    # Number of dims
    ndms = m[pos]
    pos = pos + 1
    # Dimensions
    #dms = double(typecast(m(pos:pos+ndms*4-1),'uint32')');
    dms = np.frombuffer(m[pos:pos+ndms*4], dtype=np.uint32).squeeze()
    pos = np.intp(pos + ndms*4)
    # Contents
    #v = cell([dms,1,1]);
    #len_v = dms[0] if np.prod(dms) else 0
    len_v = np.prod(np.prod((dms, 1, 1)), dtype=np.intp)
    v = [None]*len_v
    #print("Dms:", dms, "Pos:", pos, "- len(v):", len(v))
    #for ii = 1:numel(v)
    for ii in range(len_v):
      #[v{ii},pos] = deserialize_value(m,pos); end
      #print("ii", ii, "Pos:", pos, "m[pos]:", m[pos])
      v[ii], pos = deserialize_value(m, pos)
    #print("dms:", dms)
    # v = np.array(v, copy=False, ndmin=ndms)
    v_wrapper = np.empty(dms, dtype=np.object)
    c_idx = 0
    # print("Reported dms:", dms, "Resulting shape:")
    # Copied from np.ndindex() source code
    from numpy.lib.stride_tricks import as_strided
    _dms = as_strided(np.zeros(1), shape=dms, strides=np.zeros_like(dms))
    it = np.nditer(_dms, flags=['multi_index', 'zerosize_ok'], order='F')
    while not it.finished:
      elm = v[c_idx]
      #print("Dm: idx", it.multi_index, elm)
      if isinstance(elm, np.ndarray):
        elm = elm.squeeze()
      v_wrapper[it.multi_index] = elm
      c_idx += 1
      it.iternext()
    v = v_wrapper
    # print("Reported dms:", dms, "Resulting shape:", v.shape)
    # print("Returning at pos:", pos)
  elif kind == 34: # cell scalars
    # TODO: See if we can make one-line assignment here
    content, pos = deserialize_value(m, pos)
    # v = cell(size(content));
    v = np.empty(content.shape, dtype=content.dtype)
    #for k=1:numel(v)
    for k in range(len(v)):
      #v{k} = content(k); end
      v[k] = content[k]
  elif kind == 35: # mixed-real cell scalars
    content, pos = deserialize_value(m,pos)
    # v = cell(size(content));
    v = np.empty(content.shape, dtype=content.dtype)
    #for k=1:numel(v)
    for k in range(len(v)):
      #v{k} = content(k); end
      v[k] = content[k]
    # [reality,pos] = deserialize_value(m,pos);
    reality, pos = deserialize_value(m,pos)
    #v(reality) = real(v(reality));
    v[reality] = np.real(v[reality])
  elif kind == 36: # cell array with horizontal or empty strings
    chars, pos = deserialize_string(m,pos)
    lengths, pos = deserialize_numeric_simple(m,pos)
    empty, pos = deserialize_logical(m,pos)
    #v = cell(size(lengths));
    v = np.empty(lengths.shape, dtype="S1")
    # splits = [0 cumsum(double(lengths(:)))'];
    splits = np.cumsum(lengths).T
    #for k=1:length(lengths)
    v[0] =  chars[0:splits[0]]
    for k in range(len(lengths)):
      # v{k} = chars(splits(k)+1:splits(k+1)); end
      v[k+1] = chars[splits[k]:splits[k+1]]
    #[v{empty}] = deal('');
    v[empty] = _empty_str
  elif kind == 37: # empty,known type
    tag = m[pos]
    pos = pos + 1
    if tag == 1:   # double - []
      # prot = [];
      prot = np.array([], dtype=np.double) # TODO: Pre-generate if immutable
    elif tag == 33:  # cell - {}
      # prot = {};
      prot = []
    elif tag == 128: # struct - struct()
      #prot = struct();
      prot = [AttrDict()]
    else:
      raise NotImplementedError('Unsupported type tag.')
    # Number of dims
    ndms = m[pos]
    pos = pos + 1
    # Dimensions
    # dms = typecast(m(pos:pos+ndms*4-1),'uint32')';
    dms = np.frombuffer(m[pos:pos+ndms*4], dtype=np.uint32).squeeze()
    pos = np.intp(pos + ndms*4)
    # Create content
    #v = repmat({prot},dms);
    v = np.tile(prot, dms)
  elif kind == 38: # empty, prototype available
    # Prototype.
    prot, pos = deserialize_value(m,pos)
    print("Prot:", prot, "Pos:", pos)
    # Number of dims
    ndms = m[pos]
    pos = pos + 1
    # Dimensions
    #dms = typecast(m(pos:pos+ndms*4-1),'uint32')';
    dms = np.frombuffer(m[pos:pos+ndms*4], dtype=np.uint32).squeeze()
    pos = np.intp(pos + ndms*4)
    # Create content
    #v = repmat({prot},dms);
    v = np.tile([prot], dms)
  elif kind == 39: # boolean flags
    content, pos = deserialize_logical(m, pos)
    # v = cell(size(content));
    v = np.empty(content.shape, dtype=np.bool_)
    # for k=1:numel(v)
    for k in range(len(v)):
      # v{k} = content(k); end
      v[k] = content[k]
  else:
    raise NotImplementedError('Unsupported cell array type.')
  return v, pos

'''
# object
function [v,pos] = deserialize_object(m,pos)
pos = pos + 1;
# Get class name.
[cls,pos] = deserialize_string(m,pos);
# Get contents
[conts,pos] = deserialize_value(m,pos);
# construct object
try
    # try to use the loadobj function
    v = eval([cls '.loadobj(conts)']);
catch
    try
        # pass the struct directly to the constructor
        v = eval([cls '(conts)']);
    catch
        try
            # try to set the fields manually
            v = feval(cls);
            for fn=fieldnames(conts)'
                try
                    set(v,fn{1},conts.(fn{1}));
                catch
                    # Note: if this happens, your deserialized object might not be fully identical
                    # to the original (if you are lucky, it didn't matter, through). Consider
                    # relaxing the access rights to this property or add support for loadobj from
                    # a struct.
                    warn_once('hlp_deserialize:restricted_access','No permission to set property #s in object of type #s.',fn{1},cls);
                end
            end
        catch
            v = conts;
            v.hlp_deserialize_failed = ['could not construct class: ' cls];
        end
    end
end
end

# function handle
function [v,pos] = deserialize_handle(m,pos)
# Tag
kind = m(pos);
pos = pos + 1;
switch kind
    case 151 # simple function
        persistent db_simple; ##ok<TLEV> # database of simple functions (indexed by name)
        # Name
        [name,pos] = deserialize_string(m,pos);
        try
            # look up from table
            v = db_simple.(name);
        catch
            # otherwise generate & fill table
            v = str2func(name);
            db_simple.(name) = v;
        end
    case 152 # anonymous function
        # Function code
        [code,pos] = deserialize_string(m,pos);
        # Workspace
        [wspace,pos] = deserialize_struct(m,pos);
        # Construct
        v = restore_function(code,wspace);
    case 153 # scoped or nested function
        persistent db_nested; ##ok<TLEV> # database of nested functions (indexed by name)
        # Parents
        [parentage,pos] = deserialize_cell(m,pos);
        try
            key = sprintf('#s_',parentage{:});
            # look up from table
            v = db_nested.(key);
        catch
            # recursively look up from parents, assuming that these support the arg system
            v = parentage{end};
            for k=length(parentage)-1:-1:1
                # Note: if you get an error here, you are trying to deserialize a function handle
                # to a nested function. This is not natively supported by MATLAB and can only be made
                # to work if your function's parent implements some mechanism to return such a handle.
                # The below call assumes that your function uses the BCILAB arg system to do this.
                v = arg_report('handle',v,parentage{k});
            end
            db_nested.(key) = v;
        end
end
end

# helper for deserialize_handle
function f = restore_function(decl__,workspace__)
# create workspace
for fn__=fieldnames(workspace__)'
    # we use underscore names here to not run into conflicts with names defined in the workspace
    eval([fn__{1} ' = workspace__.(fn__{1}) ;']);
end
clear workspace__ fn__;
# evaluate declaration
f = eval(decl__);
end

# emit a specific warning only once (per MATLAB session)
function warn_once(varargin)
persistent displayed_warnings;
# determine the message content
if length(varargin) > 1 && any(varargin{1}==':') && ~any(varargin{1}==' ') && ischar(varargin{2})
    message_content = [varargin{1} sprintf(varargin{2:end})];
else
    message_content = sprintf(varargin{1:end});
end
# generate a hash of of the message content
str = java.lang.String(message_content);
message_id = sprintf('x#.0f',str.hashCode()+2^31);
# and check if it had been displayed before
if ~isfield(displayed_warnings,message_id)
    # emit the warning
    warning(varargin{:});
    # remember to not display the warning again
    displayed_warnings.(message_id) = true;
end
end
'''

if __name__ == "__main__":
  dump_folder = '../sertest/'

  def testVal(val, serialized_fp):
    print("Test FP:", serialized_fp.rsplit('/',1)[-1])
    def printArr(_exp, _found):
        print("Expected:\n", _exp, "- shape:", _exp.shape, "- dtype:", _exp.dtype,
              "- Result:\n", _found, "- shape:", _found.shape, "- dtype:", _found.dtype)
        #print("Subtract:\n", result - val)
    with open(serialized_fp, 'rb') as f:
      f_bytes = f.read()
      result = hlp_deserialize(f_bytes)
      if isinstance(val, AttrDict):
        def cmpDict(prev, _exp, _found):
          diff_exp = set(_exp.keys()) - set(_found.keys())
          diff_found =  set(_found.keys()) - set(_exp.keys())
          if len(diff_exp) or len(diff_found):
            print("Keys differ:", prev,
                  "- Only in expected:", diff_exp,
                  "- Keys only in found:", diff_found)
            return False
          for key, exp_val in _exp.items():
            found_val = _found[key]
            print("\nKey:", prev + "." + key,
                  "\n- Exp:", type(exp_val), exp_val,
                  "\n- Found:", type(found_val), found_val)
            if isinstance(exp_val, AttrDict):
              cmpDict(prev + "." + key, exp_val, found_val)
            elif isinstance(exp_val, str):
              if exp_val != found_val:
                print("Key:", prev + "." + key,
                      "- Exp:", exp_val, " - Found:", found_val)
                return False
            else:
              exp_val = np.atleast_1d(exp_val)
              found_val = np.atleast_1d(found_val)
              print(f"exp_val: {exp_val.dtype} =? found_val: {found_val.dtype}")
              if (exp_val != found_val).any():
                print("Key:", prev + key)
                printArr(exp_val, found_val)
                return False
            #End of loop
          return True
        assert cmpDict("", val, result)
      else:
        import scipy.sparse
        if scipy.sparse.issparse(val):
          val = val.todense()
          result = result.todense()
        if (val != result).any():
          printArr(val, result)
          assert False

  base_val = 65.2222
  increment = 1.09
  val = [base_val]
  testVal(np.uint8(val),  dump_folder + 'uint8_scalar.bin')
  testVal(np.int8(val),   dump_folder + 'int8_scalar.bin')
  testVal(np.uint16(val), dump_folder + 'uint16_scalar.bin')
  testVal(np.int16(val),  dump_folder + 'int16_scalar.bin')
  testVal(np.uint32(val), dump_folder + 'uint32_scalar.bin')
  testVal(np.int32(val),  dump_folder + 'int32_scalar.bin')
  testVal(np.uint64(val), dump_folder + 'uint64_scalar.bin')
  testVal(np.int64(val),  dump_folder + 'int64_scalar.bin')
  testVal(np.single(val), dump_folder + 'single_scalar.bin')
  testVal(np.double(val), dump_folder + 'double_scalar.bin')

  val = (base_val + np.arange(0, 12, increment)).reshape(3, 4, order='F')
  # Matlab rounds integer, use rint() to get same behavior
  val_int = np.rint(val)
  testVal(np.uint8(val_int),  dump_folder + 'uint8_mat.bin')
  testVal(np.int8(val_int),   dump_folder + 'int8_mat.bin')
  testVal(np.uint16(val_int), dump_folder + 'uint16_mat.bin')
  testVal(np.int16(val_int),  dump_folder + 'int16_mat.bin')
  testVal(np.uint32(val_int), dump_folder + 'uint32_mat.bin')
  testVal(np.int32(val_int),  dump_folder + 'int32_mat.bin')
  testVal(np.uint64(val_int), dump_folder + 'uint64_mat.bin')
  testVal(np.int64(val_int),  dump_folder + 'int64_mat.bin')
  testVal(np.single(val),     dump_folder + 'single_mat.bin')
  testVal(np.double(val),     dump_folder + 'double_mat.bin')

  # Use save val as last time and add cmplx part to it
  cmplx_rng = np.linspace(1, 12*increment, 12).reshape(3, 4, order='F')
  cmplx_int = np.rint(cmplx_rng)*1j # MATLAB rounds the complex part, huh.
  testVal(np.uint8(val_int) +  cmplx_int,  dump_folder + 'uint8_cmplx.bin')
  testVal(np.int8(val_int) +   cmplx_int,  dump_folder + 'int8_cmplx.bin')
  testVal(np.uint16(val_int) + cmplx_int,  dump_folder + 'uint16_cmplx.bin')
  testVal(np.int16(val_int) +  cmplx_int,  dump_folder + 'int16_cmplx.bin')
  testVal(np.uint32(val_int) + cmplx_int,  dump_folder + 'uint32_cmplx.bin')
  testVal(np.int32(val_int) +  cmplx_int,  dump_folder + 'int32_cmplx.bin')
  testVal(np.uint64(val_int) + cmplx_int,  dump_folder + 'uint64_cmplx.bin')
  testVal(np.int64(val_int) +  cmplx_int,  dump_folder + 'int64_cmplx.bin')
  testVal(np.single(val) + np.single(cmplx_rng)*1j,  dump_folder + 'single_cmplx.bin')
  # testVal(np.double(val) + np.double(cmplx_rng)*1j,  dump_folder + 'double_cmplx.bin')

  testVal(np.bool_([True]),  dump_folder + 'logical_true.bin')
  testVal(np.bool_([False]), dump_folder  +'logical_false.bin')
  val = np.tile(np.bool_([True, False]), (4, 2))
  #print("Bool arr:", np.tile(np.bool_([True, False]), (4, 2)))
  testVal(val, dump_folder + 'logical_mat.bin')

  testVal(np.array(['c'], dtype="S1"), dump_folder + 'chr_c.bin')
  testVal(np.array(list('Hello World'), dtype="S1"), dump_folder + 'chr_hello_w_arr.bin')
  testVal(np.array([], dtype="S1"), dump_folder + 'chr_empty.bin')
  from string import ascii_lowercase
  val = np.array(list(ascii_lowercase[:20]),dtype="S1").reshape(5, 4, order='F')
  testVal(val, dump_folder + 'chr_mat.bin')

  # hlp_serialize uses the term string to refer to char array. Look at
  # hlp_serialize.serialize_string
  # dumpFile(hlp_serialize("s"),[dump_folder 's_str.bin']);
  # dumpFile(hlp_serialize("Hello World"),[dump_folder 'hello_w_str.bin']);
  # dumpFile(hlp_serialize(""),[dump_folder 'empty_str.bin']);

  # Create as np.double() sparse matrix to match MATLAB's values
  val = bsr_matrix(np.double(np.diag([10, 11, 12, 13])))
  testVal(val, dump_folder + 'sparse_diag.bin')

  val = AttrDict()
  val.int = np.int64(64)
  val.float = np.single(1.22)
  val.char_arr = np.array(list('abcde'), dtype="S1")
  val.y = AttrDict()
  val.y.x = AttrDict()
  val.y.x.int = np.arange(1,1025, dtype=np.double) # nested struct
  testVal(val, dump_folder + 'struct.bin')

  val = AttrDict()
  val.empty = np.empty((0))
  val.cell_arr = np.empty((0))
  val.empty_cell = np.empty((0))
  testVal(val, dump_folder + 'struct_empty.bin')

  val = AttrDict()
  val.f1 = np.tile(np.array([1, 2, 3], dtype=np.double), (3, 1))
  val.f2 = np.tile(np.array(list('abc'), dtype="S1"), (3, 1))
  val.f3 = np.array([0.5, 1.0, 1.5], dtype=np.double)
  testVal(val, dump_folder + 'struct2.bin')

'''
  val = ObjDumpTest();
  dumpFile(hlp_serialize(val),[dump_folder 'class_ObjDumpTest.bin']);


  dumpFile(hlp_serialize(@dumpFile),[dump_folder 'func_free.bin']);
  dumpFile(hlp_serialize(@(x) x.^2),[dump_folder 'func_anonymous.bin']);
  '''