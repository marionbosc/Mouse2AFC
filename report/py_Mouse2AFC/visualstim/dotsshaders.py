import ctypes
import pyglet
pyglet.options['debug_gl'] = False
import pyglet.gl as GL

# Copied from PsychoPy's PsychImagingPipelineSupport.c
# PsychCreateGLSLProgram()
#  Try to create GLSL shader from source strings and return handle to new shader.
#  Returns the shader handle if it worked, 0 otherwise.
#
#  fragmentsrc  - Source string for fragment shader. NULL if none needed.
#  vertexsrc    - Source string for vertex shader. NULL if none needed.
#  primitivesrc - Source string for primitive shader. NULL if none needed.
#
#  Return value: GLuint
def CreateGLSLProgram(fragmentsrc, vertexsrc, debug=False,
                      print_shaders_code=False):
  shader = GL.GLuint()
  status = GL.GLint()
  errtxt = ctypes.create_string_buffer(10000)
  # Reset error state:
  while GL.glGetError():
    pass
  # Supported at all on this hardware?
  available_exetensions = GL.gl_info.get_extensions()
  if "GL_ARB_shader_objects" not in available_exetensions or \
     "GL_ARB_shading_language_100" not in available_exetensions:
    if debug:
      print("GLSPRogram-ERROR: Your graphics hardware does not support GLSL "
            "fragment shaders! Use of imaging pipeline with current settings "
            "impossible!")
    return 0
  # Create GLSL program object:
  glsl = GL.glCreateProgram()
  # Fragment shader wanted?
  if fragmentsrc:
    if print_shaders_code:
      print("GLSPRogram: Creating the following fragment shader, GLSL source "
            f"code follows:\n\n{fragmentsrc}\n")
    # Supported on this hardware?
    if "GL_ARB_fragment_shader" not in available_exetensions:
      print("GLSPRogram-ERROR: Your graphics hardware does not support GLSL "
            "fragment shaders! Use of imaging pipeline with current settings "
            "impossible!")
      return 0
    # Create shader object:
    shader = GL.glCreateShader(GL.GL_FRAGMENT_SHADER)
    # Create a C string buf
    fragmentsrc = ctypes.create_string_buffer(fragmentsrc)
    fragmentsrc = ctypes.cast(ctypes.pointer(fragmentsrc), # Get a pointer
                          ctypes.POINTER(GL.GLchar))
    # Feed it with GLSL source code:
    GL.glShaderSource(shader, 1, ctypes.byref(fragmentsrc), None)
    # Compile shader:
    GL.glCompileShader(shader)

    GL.glGetShaderiv(shader, GL.GL_COMPILE_STATUS, ctypes.byref(status))
    if status.value != GL.GL_TRUE:
      if debug:
        print("GLSPRogram-ERROR: Shader compilation for builtin fragment "
              "shader failed:")
        GL.glGetShaderInfoLog(shader, 9999, None, errtxt)
        print(f"{errtxt.value}\n")
      GL.glDeleteShader(shader)
      GL.glDeleteProgram(glsl)
      # Failed!
      while GL.glGetError():
        pass
      return 0
    # Attach it to program object:
    GL.glAttachShader(glsl, shader)

  # Vertex shader wanted?
  if vertexsrc:
    if print_shaders_code:
      print("GLSPRogram: Creating the following vertex shader, GLSL source "
            f"code follows:\n\n{vertexsrc}\n")
    # Supported on this hardware
    if "GL_ARB_vertex_shader" not in available_exetensions:
      if debug:
         print("GLSPRogram-ERROR: Your graphics hardware does not support GLSL "
               "vertex shaders! Use of imaging pipeline with current settings "
               "impossible!")
      return 0
    # Create shader object:
    shader = GL.glCreateShader(GL.GL_VERTEX_SHADER)
    # Create a C string buffer, no clue how it's done though
    vertexsrc = ctypes.create_string_buffer(vertexsrc)
    vertexsrc = ctypes.cast(ctypes.pointer(vertexsrc), # Get a pointer
                            ctypes.POINTER(GL.GLchar))
    GL.glShaderSource(shader, 1, ctypes.byref(vertexsrc), None)
    # Compile shader:
    GL.glCompileShader(shader)

    GL.glGetShaderiv(shader, GL.GL_COMPILE_STATUS, ctypes.byref(status))
    if status.value != GL.GL_TRUE:
      if debug:
        print("GLSPRogram-ERROR: Shader compilation for builtin vertex shader "
              "failed:")
        GL.glGetShaderInfoLog(shader, 9999, None, errtxt)
        print(f"{errtxt.value}\n")
      GL.glDeleteShader(shader)
      GL.glDeleteProgram(glsl)
      # Failed!
      while GL.glGetError():
        pass
      return 0
    # Attach it to program object:
    GL.glAttachShader(glsl, shader)

  # Link into final program object:
  GL.glLinkProgram(glsl)
  # Check link status:
  GL.glGetProgramiv(glsl, GL.GL_LINK_STATUS, ctypes.byref(status))
  if status.value != GL.GL_TRUE:
    if debug:
      print("GLSPRogram-ERROR: Shader link operation for builtin glsl program "
            "failed.")
      GL.glGetProgramInfoLog(glsl, 9999, None, errtxt)
      print(f"{errtxt.value}\n")
    GL.glDeleteProgram(glsl)
    # Failed!
    while GL.glGetError():
      pass
    return 0

  while GL.glGetError():
    pass
  # Return new GLSL program object handle:
  return glsl

# Copied from Psychtoolbox's PsychWindowSupport.c
# PsychSetShader() -- Lazily choose a GLSL shader to use for further operations.
#
# The routine shall bind the shader 'shader' for the OpenGL context of window
# 'windowRecord'. It assumes that the OpenGL context for that windowRecord is
# already bound.
#
# This is a wrapper around glUseProgram(). It does nothing if GLSL isn't supported,
# ie. if gluseProgram() is not available. Otherwise it checks the currently bound
# shader and only rebinds the new shader if it isn't already bound - avoiding redundant
# calls to glUseProgram() as such calls might be expensive on some systems.
#
# A 'shader' value of zero disables shading and enables fixed-function pipe, as usual.
# A positive value sets the shader with that handle. Negative values have special
# meaning in that the select special purpose shaders stored in the 'windowRecord'.
#
# Currently the value -1 is defined to choose the windowRecord->defaultDrawShader.
# That shader can be anything special, zero for fixed function pipe, or e.g., a shader
# to disable color clamping.
#
def SetShader(shader):
  # Have GLSL support?
  if GL.glUseProgram:
    # Choose this windowRecords assigned default draw shader if shader == -1:
    if shader == -1:
      raise RuntimeError("Shouldn't Happen we should have a valud shader here")
      #shader = (int) windowRecord->defaultDrawShader
    if shader < -1:
      print(f"SetShader-BUG: Invalid shader id {shader} requested in "
            "PsychSetShader()! Switching to fixed function.")
      shader = 0
    # Query currently bound shader:
    oldShader = GetCurrentShader()
    # Switch required? Switch if so:
    if shader != oldShader:
      GL.glUseProgram(shader)
  else:
    shader = 0
  # Return new bound shader (or zero in case of fixed function only):
  return shader

# Copied from Psychtoolbox's PsychWindowSupport.c
# PsychGetCurrentShader() - Returns currently bound GLSL
# program object, if any. Returns 0 if fixed-function pipeline
# is active.
#
# This needs to distinguish between OpenGL 2.0 and earlier.
#
def GetCurrentShader():
  curShader = GL.GLint()
  # if GL.GLEW_VERSION_2_0:
  #   GL.glGetIntegerv(GL.GL_CURRENT_PROGRAM, ctypes.byref(curShader))
  # else:
  curShader =  GL.glGetHandleARB(GL.GL_PROGRAM_OBJECT_ARB)
  return curShader


def dotsSizeRange(win):
  win.setScale('pix')
  # Copied from PsychtoolBox SCREENDrawDots but yields in different results
  _float = (GL.GLfloat*2)()
  GL.glGetFloatv(GL.GL_ALIASED_POINT_SIZE_RANGE, _float)
  min_aliased_point_size, max_aliased_point_size = _float[0], _float[1]
  print("min/max aliased_point_size:", list(_float))

  GL.glGetFloatv(GL.GL_POINT_SIZE_RANGE, _float)
  min_smooth_point_Size, max_smooth_point_size = _float[0], _float[1]

  return (min_smooth_point_Size, max_smooth_point_size, min_aliased_point_size,
          max_aliased_point_size)
