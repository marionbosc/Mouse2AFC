import numpy as np
from psychopy import core
from psychopy.tools.monitorunittools import deg2pix
import pyglet.gl as GL
from psychopy import visual
from common.definitions import DrawStimType
from common.loadSerializedData import loadSerializedData
from . import dotsshaders as ds
from .checkclose import checkClose

CIRCLE_RDK = False # TODO: Ready from Incoming params
class DrawDots:
  def __init__(self, wins_ptrs, win_size, photo_diode_size, photo_diode_pos,
               frame_rate, monitor):
    self._wins_ptrs = wins_ptrs
    self._win_size = win_size
    self._frame_rate = frame_rate
    self._monitor = monitor

    self._fill_rects = []
    self._photo_diode_boxes = []
    self._pix_scale = []
    for cur_win_ptr in self._wins_ptrs:
      rect = visual.Rect(cur_win_ptr, units="norm",  pos=(0, 0), size=(2, 2),
                         fillColor="black", lineColor="black")
      self._fill_rects.append(rect)
      box = visual.Rect(cur_win_ptr, units="norm", fillColor="white",
                        lineColor="white",  pos=photo_diode_pos,
                        size=photo_diode_size)
      self._photo_diode_boxes.append(box)
      # Next part is adapted from psychopy's visual.window.py:setScale()
      prev_scale = np.asarray((1.0, 1.0))
      this_scale = (2.0 / win_size) *  (2 if cur_win_ptr.useRetina else 1)
      self._pix_scale.append(this_scale/prev_scale)
    # Maybe converting it to numpy would yield faster looping?
    self._fill_rects = np.array(self._fill_rects)
    self._photo_diode_boxes = np.array(self._photo_diode_boxes)
    self._pix_scale = np.array(self._pix_scale)

    # Create a very big buffer to hold the dots
    self._dots_arr_buf = np.empty((50000, 2)) # 2: Prepare for x,y
    print("_dots_arr_buf", self._dots_arr_buf.dtype)
    # actually set the scale as appropriate
    # allows undoing of a previous scaling procedure
    # _dots array will be set later as a slice of self.dots_arr_buf. It's being
    # used to reuse memory and in the hope to to speed computations.
    self._dots_arr = None
    # Create all the self._directions that we have
    self._directions = np.arange(0,360,45)
    self._directionsRatios = np.empty(len(self._directions))
    # TODO: Ooptimize the next variable
    self._direction_ndots = None
    # Distance traveled in ch frame movement for each self._directions' x,y
    self._dxy = np.empty((len(self._directions), 2))
    self._rnd_gen = np.random.default_rng()
    # Variables for handling dots shaders. Flag that we didn't attempt yet to
    # compile shaders
    self._smooth_point_shader = None
    self._attempted_gen_shaders = False
    # Assume all the windows are the same
    (min_smooth_point_Size, max_smooth_point_size, min_aliased_point_size,
      max_aliased_point_size) = ds.dotsSizeRange(self._wins_ptrs[0])
    print(f"minSmoothPointSize: {min_smooth_point_Size} - "
          f"max_smooth_point_size: {max_smooth_point_size}")
    print(f"minAliasedPointSize: {min_aliased_point_size} - "
          f"maxAliasedPointSize: {max_aliased_point_size}")
    self._max_smooth_point_size = max_smooth_point_size

  def loop(self, cur_cmd, mm_file):
    # Disable anti-aliasing for dots initially
    GL.glDisable(GL.GL_POINT_SMOOTH)
    while True:
      checkClose(self._wins_ptrs)
      # Either this is the first run or the next iteration, in both way, clear
      # the screen to prepare for the next run.
      for win_ptr, fill_rect in zip(self._wins_ptrs, self._fill_rects):
        fill_rect.draw()
        win_ptr.waitBlanking = False
        win_ptr.flip(clearBuffer=False)
        win_ptr.waitBlanking = True
      # Keep waiting until we receive the load or run command
      while cur_cmd == 0:
        core.wait(0.01) # Sleep until the next command
        cur_cmd = np.frombuffer(mm_file[:4], dtype=np.uint32)[0]

      # Load the the drawing parameters
      _, drawParams = loadSerializedData(mm_file, 4)
      if drawParams.stimType != DrawStimType.RDK:
        return cur_cmd, drawParams

      renderLoop_args = self._load(drawParams)
      cur_cmd = self._renderLoop(mm_file, *renderLoop_args)
    # We can only break if we want exit
    print("User asked to exit")
    return -1, None

  def _load(self, drawParams):
    if CIRCLE_RDK:
      field_area = np.pi*((drawParams.apertureSizeWidth/2)*
                          (drawParams.apertureSizeHeight/2))
    else:
      field_area = drawParams.apertureSizeWidth * \
                   drawParams.apertureSizeHeight
    # Convert area to pixels, but seqare it to get the whole area. We square
    # only the width as deg2pix() uses the width only.
    field_area_pix = (drawParams.apertureSizeWidth*self._win_size[0]) * \
                     (drawParams.apertureSizeHeight*self._win_size[1])
    # Calculate the size of a dot in pixel
    self._monitor.setWidth(drawParams.screenWidthCm)
    self._monitor.setDistance(drawParams.screenDistCm)
    dot_size_pix = deg2pix(drawParams.dotSizeInDegs, monitor=self._monitor)
    ##
    scrHeightCm = self._monitor.getWidth()
    scrSizePix = self._monitor.getSizePix()
    from psychopy.tools.monitorunittools import deg2cm
    cmSize = deg2cm(drawParams.dotSizeInDegs, self._monitor, correctFlat=False)
    dot_size_heightDeg = cmSize * scrSizePix[1] / float(scrHeightCm)
    ##
    dot_type = 1
    # if dot_size_pix > self._max_smooth_point_size:
    #   dot_type = 3
    # dot_size_pix is squared to account for area in 2-d rather than 1-d
    print(f"Field size pix: {field_area_pix} - Dot size pix: {dot_size_pix}")
    scaled_draw_ratio = (drawParams.drawRatio*field_area_pix)/(dot_size_pix*dot_size_heightDeg)
    nDots = np.around(scaled_draw_ratio)

    # First we'll calculate the left, right top and bottom of the
    # aperture (in degrees)
    # Apreture size between 0 and 1, We need to multiple by 2 to normalize
    # 0:2 to -1:1 then divide by 2, So basically we will just use the
    # apertureSize as its current value.
    l =  drawParams.centerX - drawParams.apertureSizeWidth/2
    r =  drawParams.centerX + drawParams.apertureSizeWidth/2
    b =  drawParams.centerX - drawParams.apertureSizeHeight/2
    t =  drawParams.centerX + drawParams.apertureSizeHeight/2
    # print(f"l: {l} - r: {r} - b: {b} - t: {t}")

    # Calculate ratio of incoherent for each direction so can use it later
    # to know how many dots should be per each direction. The ratio is
    # equal to the total incoherence divide by the number of self._directions
    # minus one. A coherence of zero has equal opportunity in all
    # self._directions, and thus the main direction ratio is the normal
    # coherence plus the its share of random incoherence.
    directionIncoherence = (1-drawParams.coherence)/len(self._directions)
    self._directionsRatios[:] = directionIncoherence
    self._directionsRatios[self._directions == drawParams.mainDirection] += \
                                                            drawParams.coherence
    # Round the number of dots that we have such that we get whole number
    # for each direction
    self._direction_ndots = np.rint(self._directionsRatios * nDots).astype(np.int)
    # Re-evaluate the number of dots. Convert to int and create as an
    # array so we can pass it as a list.
    nDots = np.int(self._direction_ndots.sum(),)
    # Convert lifetime to number of frames
    lifetime = np.ceil(drawParams.dotLifetimeSecs * self._frame_rate)
    # Each dot will have a integer value 'life' which is how many frames the
    # dot has been going.  The starting 'life' of each dot will be a random
    # number between 0 and dotsParams.lifetime-1 so that they don't all 'die'
    # on the same frame:
    dots_life = np.ceil(self._rnd_gen.random(nDots)*lifetime)
    # The distance traveled by a dot (in degrees) is the speed (degrees/second)
    # divided by the frame rate (frames/second). The units cancel, leaving
    # degrees/frame which makes sense. Basic trigonometry (sines and cosines)
    # allows us to determine how much the changes in the x and y position.
    dot_speed_norm = deg2pix(drawParams.dotSpeed, self._monitor)/self._win_size
    print("Dot speed pix:", dot_speed_norm)
    self._dxy[:,0] = (dot_speed_norm[0]*np.sin(self._directions*np.pi/180)/
                      self._frame_rate)
    self._dxy[:,1] = (-dot_speed_norm[1]*np.cos(self._directions*np.pi/180)/
                      self._frame_rate)
    #print("self._dxy:", self._dxy)
    # Take a slice of the original array, Second dimension has length of 2
    # for x and y
    self._dots_arr = self._dots_arr_buf[:nDots, :]
    print("nDots", nDots, "Dots arr shape:", self._dots_arr.shape)
    # Create all the dots in random starting positions between -0.5 to +0.5 on
    # both x and y axes
    self._dots_arr = self._rnd_gen.random(self._dots_arr.shape,
                                          out=self._dots_arr) - 0.5
    self._dots_arr[:,0] *= drawParams.apertureSizeWidth + drawParams.centerX
    self._dots_arr[:,1] *= drawParams.apertureSizeHeight + drawParams.centerY

    # Next part is adapted from Psychtoolbox
    if dot_type in (1, 2):
      # Psychtoolbox: A dot type of 2 requests highest quality point smoothing
      GL.glEnable(GL.GL_POINT_SMOOTH)
      GL.glHint(GL.GL_POINT_SMOOTH_HINT,
                GL.GL_NICEST if dot_type == 2 else GL.GL_DONT_CARE)
    else:
      self._handleShaders(dot_type)
    # GL.glGetFloatv(GL.GL_ALIASED_POINT_SIZE_RANGE, (GLfloat*) &pointsizerange);
    # Need this when drawing the dots later
    return (dot_size_pix, dots_life, lifetime, drawParams.apertureSizeWidth,
            drawParams.apertureSizeHeight, drawParams.centerX,
            drawParams.centerY, (l, r, b, t), dot_type)

  def _renderLoop(self, mm_file, dot_size_pix, dots_life, lifetime,
                  aperture_size_width, aperture_size_height, center_x, center_y,
                  l_r_b_t, dot_type):
    l, r, b, t = l_r_b_t
    ifi = 1/self._frame_rate
    cur_cmd = 2 # This function should have not been called if cur_cmd is not 2
    next_frame_time = 0

    cur_cmd = np.frombuffer(mm_file[:4], dtype=np.uint32)[0]
    # TODO: Send trial number as well to check if we missed a whole trial and
    # accordingly if we should load a new config
    while cur_cmd == 1:
      core.wait(0.005) # Wait for the run command
      cur_cmd = np.frombuffer(mm_file[:4], dtype=np.uint32)[0]
      checkClose(self._wins_ptrs)

    while cur_cmd == 2:
      if CIRCLE_RDK:
        good_dots = \
          (self._dots_arr[:,0]-center_x)**2/(aperture_size_width/2)**2 + \
          (self._dots_arr[:,1]-center_y)**2/(aperture_size_height/2)**2 < 1
        #convert from degrees to screen pixels
        pixpos = (self._dots_arr-0.5) * self._win_size + self._win_size/2
        good_dots_pix = pixpos[good_dots]
      else:
        good_dots_pix = (self._dots_arr-0.5) * self._win_size + self._win_size/2

      #print("Good dots:", good_dots_pix)
      for idx in np.arange(len(self._wins_ptrs)):
        # Modified from Psychopy's DotsStim.Draw()
        self._wins_ptrs[idx]._setCurrent()
        GL.glPushMatrix()  # push before drawing, pop after
        if dot_type >= 3:
          GL.glMultiTexCoord1f(GL.GL_TEXTURE2, dot_size_pix)
          GL.glUseProgram(self._smooth_point_shader)
        # draw the dots
        # Either call the next setScale() or do what it does
        #cur_win_ptr.setScale('pix') # It's necessary to call this function here
        pix_scale = self._pix_scale[idx]
        GL.glScalef(pix_scale[0], pix_scale[1], 1.0)
        GL.glPointSize(dot_size_pix)
        # load Null textures into multitexteureARB - they modulate with
        # glColor
        # GL.glActiveTexture(GL.GL_TEXTURE0)
        # GL.glEnable(GL.GL_TEXTURE_2D)
        # GL.glBindTexture(GL.GL_TEXTURE_2D, 0)
        # GL.glActiveTexture(GL.GL_TEXTURE1)
        # GL.glEnable(GL.GL_TEXTURE_2D)
        # GL.glBindTexture(GL.GL_TEXTURE_2D, 0)
        GL.glVertexPointer(2, GL.GL_DOUBLE, 0, good_dots_pix.ctypes.data)
        #desiredRGB = self._getDesiredRGB(rgb, colorSpace, contrast)
        #GL.glColor4f(desiredRGB[0], desiredRGB[1], desiredRGB[2],
        #             opacity)
        GL.glColor4f(1, 1, 1, 1) # White (r, g, b) at full opacity
        GL.glEnableClientState(GL.GL_VERTEX_ARRAY)
        GL.glDrawArrays(GL.GL_POINTS, 0, good_dots_pix.shape[0])
        GL.glDisableClientState(GL.GL_VERTEX_ARRAY)
        # GL.glVertexPointer(2, GL.GL_DOUBLE, 0, 0)
        GL.glPopMatrix()
      # Update the dots for each direction
      firstIdx = 0
      lastIdx = 0
      for directionIdx in range(len(self._directions)):
        lastIdx = lastIdx + self._direction_ndots[directionIdx]
        # Update the dot position
        self._dots_arr[firstIdx:lastIdx] += self._dxy[directionIdx]
        firstIdx = lastIdx
      # Move the dots that are outside the aperture back one aperture
      # width.
      self._dots_arr[self._dots_arr[:,0]<l,0] += aperture_size_width
      self._dots_arr[self._dots_arr[:,0]>r,0] -= aperture_size_width
      self._dots_arr[self._dots_arr[:,1]<b,1] += aperture_size_height
      self._dots_arr[self._dots_arr[:,1]>t,1] -= aperture_size_height
      # Increment (or rather decrement) the 'life' of each dot
      dots_life = dots_life + 1
      #find the 'dead' dots
      dead_dots_idxs = np.where((dots_life % lifetime) == 0)[0]
      # Replace the positions of the dead dots to a random location
      if dead_dots_idxs.shape[0]:
        # Use store location from the end of the dots buffer array
        dead_dots = self._dots_arr_buf[-dead_dots_idxs.shape[0]:,:]
        #print("Dead dots:", dead_dots)
        #print("Dead dots life:", dots_life[dead_dots_idxs])
        dead_dots = self._rnd_gen.random(dead_dots.shape, out=dead_dots) - 0.5
        dead_dots[:,0] *= aperture_size_width + center_x
        dead_dots[:,1] *= aperture_size_height + center_y
        #print("new replacing dots:", dead_dots)
        # Assign back to original array
        self._dots_arr[dead_dots_idxs] = dead_dots
        #print("Deda dots idxss:", dead_dots_idxs)
        dots_life[dead_dots_idxs] = 1
      # Finally draw the corner box for the photo diode to detect
      [box.draw() for box in self._photo_diode_boxes]
      # Now we can render
      sleep_for = next_frame_time - core.monotonicClock.getTime()
      if sleep_for > 0:
        core.wait(sleep_for)
      vbl = self._wins_ptrs[0].flip()
      next_frame_time = vbl + (0.5*ifi)
      for cur_win_ptr in self._wins_ptrs[1:]:
        cur_win_ptr.waitBlanking = False
        cur_win_ptr.flip()
        cur_win_ptr.waitBlanking = True
      # Read the new command and prepare to quit if we shouldn't keep on
      # rendering
      cur_cmd = np.frombuffer(mm_file[:4], dtype=np.uint32)[0]
    return cur_cmd

  def _handleShaders(self, dot_type):
    if not self._attempted_gen_shaders:
      from .dotsshaderscode import PointSmoothFragmentShaderSrc, \
                                   PointSmoothVertexShaderSrc
      PsychtoolBox_COMPILE = True
      if PsychtoolBox_COMPILE:
        self._smooth_point_shader = ds.CreateGLSLProgram(
           PointSmoothFragmentShaderSrc, PointSmoothVertexShaderSrc, debug=True)
      else:
        from OpenGL.GL.shaders import compileProgram, compileShader
        self._smooth_point_shader = compileProgram(
            compileShader(PointSmoothVertexShaderSrc, GL.GL_VERTEX_SHADER),
            compileShader(PointSmoothFragmentShaderSrc, GL.GL_FRAGMENT_SHADER))
      print("Shaders:", self._smooth_point_shader)
      self._attempted_gen_shaders = True

    if self._smooth_point_shader:
      GL.glUseProgram(self._smooth_point_shader)
      # ^ Or we can use SetShader(self._smooth_point_shader)
      GL.glActiveTexture(GL.GL_TEXTURE1)
      GL.glTexEnvi(GL.GL_POINT_SPRITE, GL.GL_COORD_REPLACE, GL.GL_TRUE)
      GL.glActiveTexture(GL.GL_TEXTURE0)
      GL.glEnable(GL.GL_POINT_SPRITE)
      # Tell shader from where to get its color information: Unclamped
      # high precision colors from texture coordinate set 0, or regular
      # colors from vertex color attribute?
      DefaultDrawShader = 0 # 1 or 0, zero by default
      GL.glUniform1i(GL.glGetUniformLocation(self._smooth_point_shader,
                                             b"useUnclampedFragColor"),
                     DefaultDrawShader)
      # Tell shader if it should shade smooth round dots, or square dots
      GL.glUniform1i(GL.glGetUniformLocation(self._smooth_point_shader,
                                             b"drawRoundDots"),
                     1 if dot_type == 3 else 0)
      # Tell shader about current point size in pointSize uniform:
      GL.glEnable(GL.GL_PROGRAM_POINT_SIZE)
      GL.glDisable(GL.GL_POINT_SMOOTH)
