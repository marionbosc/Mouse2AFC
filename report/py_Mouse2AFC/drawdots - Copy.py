# A modified version from the code found in:
# http://www.mbfys.ru.nl/~robvdw/DGCN22/PRACTICUM_2011/LABS_2011/ALTERNATIVE_LABS/Lesson_2.html#18
from definitions import DrawStimType
from loadSerializedData import loadSerializedData
import numpy as np
# Psychopy imports
from psychopy import prefs
prefs.general['winType'] = "glfw"
from psychopy.tools.monitorunittools import deg2pix
from psychopy import visual


def availableScreensIds():
  #return Screen('Screens') # Return array of ints
  return (0, 1)

def SkipSyncTests():
  # Screen('Preference', 'SkipSyncTests', 1)
  pass

def dotsSizeRange(win):
  win._setCurrent()
  # Copied from PsychtoolBox SCREENDrawDots but yields in different results
  _float = (GL.GLfloat*2)()
  GL.glGetFloatv(GL.GL_ALIASED_POINT_SIZE_RANGE, _float)
  min_aliased_point_size, max_aliased_point_size = _float[0], _float[1]
  print("min/max aliased_point_size:", list(_float))

  GL.glGetFloatv(GL.GL_POINT_SIZE_RANGE, _float)
  min_smooth_point_Size, max_smooth_point_size = _float[0], _float[1]

  return (min_smooth_point_Size, max_smooth_point_size, min_aliased_point_size,
          max_aliased_point_size)


def createWindow(screen_id):
  BLACK_COLOR=-1
  win = visual.Window(screen=screen_id, wintype="glfw", fullscr=True,
                      bpc=32, depthBits=32, waitBlanking=True,
                      color=BLACK_COLOR, allowGUI=False)
                      # Should we add also stencil bits = 32?
  return win, win.viewport

TEMP_EXECUTE = False
def drawDots():
  from createMMFile import createMMFile
  FILE_SIZE = 512*1024 # 512 kb mem-mapped file
  m = createMMFile(r"c:\Bpoduser\mmap_matlab_randomdot.dat", FILE_SIZE)
  tic()
  print("Mapping file took: ", toc())

  tic()
  # Setup PTB with some default values
  #PsychDefaultSetup(2)
  import sys
  print("Len sys.argv:", len(sys.argv))
  if len(sys.argv) == 1:
    # Set the screen number to the external secondary monitor if there is one
    # connected
    screens_ids = [max(availableScreensIds())]
  else:
    screens_ids = [int(screen_id) for screen_id in sys.argv[1:]]
  screens_ids = np.array(screens_ids)

  # Skip sync tests for demo purposes only
  SkipSyncTests()

  BLACK_COLOR = 'black'
  WHITE_COLOR = 'white'
  GRAY_COLOR = 'gray' #(WHITE_COLOR+BLACK_COLOR)/2
  #INC_GRAY = WHITE_COLOR-GRAY_COLOR
  bkg_clr = BLACK_COLOR
  photo_diode_clr = WHITE_COLOR

  wins_ptrs = []
  fill_rects = []
  photo_diode_boxes = []
  attempted_gen_shaders = False
  smooth_point_shader = None
  # Open the screens
  print("Screens ids:", screens_ids)
  for cur_screen_id in screens_ids:
      cur_win_rect = [] # [0 0 600 600]
      print("Opening screen:", cur_screen_id)
      #cur_win_ptr, cur_win_rect = PsychImaging('OpenWindow', cur_screen_id,
      #    BLACK_COLOR, cur_win_rect, 32, 2, [], [],  kPsychNeed32BPCFloat)
      cur_win_ptr, cur_win_rect = createWindow(cur_screen_id)
      # Store a reference to the variables we need
      #winsRects = [winsRects cur_win_rect]
      wins_ptrs.append(cur_win_ptr)
      # Disable alpha blending just in case it was still enabled by a previous
      # run that crashed.
      cur_win_ptr.blendMode = "avg"
      fill_rects.append(visual.Rect(cur_win_ptr, units="norm", pos=(0, 0),
                                    size=(2, 2), fillColor=bkg_clr,
                                    lineColor=bkg_clr))
      print("Cur win rect:", cur_win_rect)
      photo_diode_boxes.append(
        # Top right part of the screen
        visual.Rect(cur_win_ptr, units="norm", fillColor=photo_diode_clr,
                    pos=(0.925, 0.925),#(cur_win_rect[2]-cur_win_rect[2]/15, 0),
                    size=(0.3, 0.15)))
  # Screen('BlendFunction', cur_win_ptr, GL_ONE, GL_ZERO)

  wins_ptrs = np.array(wins_ptrs)
  fill_rects = np.array(fill_rects)
  photo_diode_boxes = np.array(photo_diode_boxes)
  # Again, for verbosity, the same windows rect is valid for all screens as all
  # the screens should have the same resolution
  win_size = np.array((wins_ptrs[0].viewport[2] - wins_ptrs[0].viewport[0],
                       wins_ptrs[0].viewport[3] - wins_ptrs[0].viewport[1]))
  print("Setting up screen(s) took:", toc())


  (min_smooth_point_Size, max_smooth_point_size, min_aliased_point_size,
   max_aliased_point_size) = dotsSizeRange(wins_ptrs[0])
  print(f"minSmoothPointSize: {min_smooth_point_Size} - max_smooth_point_size: "
        f"{max_smooth_point_size}")
  print(f"minAliasedPointSize: {min_aliased_point_size} - maxAliasedPointSize: "
        f"{max_aliased_point_size}")

  tic()
  from psychopy.monitors import getAllMonitors, Monitor
  monitors_names = getAllMonitors()
  monitor = Monitor(monitors_names[0])
  #[width, height]=Screen(?WindowSize?, windowPointerOrScreenNumber [, realFBSize=0])

  # For the next parts, we assume that all the screens has the same dimension, so
  # just use cur_win_rect and cur_win_ptr as they should hold the sane values.

  # Query maximum useable priority_level on this system:
  #priority_level = MaxPriority(cur_screen_id)

  #ifi = Screen('GetFlipInterval', cur_win_ptr)
  frame_rate = cur_win_ptr.getActualFrameRate() #1/ifi
  ifi = 1/frame_rate

  # Create a buffer to hold the dots
  dots_arr_buf = np.empty((50000, 2)) # Initialize number of dots used in x,y
  print("Dots_arr_buf", dots_arr_buf.dtype)
  # Create all the directions that we have
  directions = np.arange(0,360,45)
  directionsRatios = np.empty(len(directions))
  # Distance traveled in ch frame movement for each directions' x,y
  dxy = np.empty((len(directions), 2))

  rnd_gen = np.random.default_rng()

  # 1 0 stop running  - load data - 2 keep running
  cur_cmd = 0
  already_loaded = 0
  already_stopped = 0

  DONT_SYNC = 1

  next_frame_time = 0
  already_cleared = True
  # next_frame_time2 = GetSecs() # Any initial value
  print("Post setup took:", toc())

  stim_type = 0
  last_stim_type = 0
  alpha_blend_used_last = False

  CIRCLE_RDK = False
  # Commands
  # 0 = Stop running
  # 1 = Load new Dots info
  # 2 = Start running or keep running
  #cur_cmd = 1
  while True:
    cur_cmd = np.frombuffer(m[:4], dtype=np.uint32)[0]
    if cur_cmd == 2 and already_loaded: # keep running
      # The code order is messy but since I'm no expert in MATLAB so
      # I'm trying my best here to get the best performance. We place
      # the most probable branch of the if-condition first, and the next
      # step is basically the last step of the code below outside of the
      # if conditions. What we've done below is that we've prepared every
      # thing in the background for flipping and we only need to flip now
      # in the right second.
      # tic
      #disp('Next frame remaining time: ' + string(next_frame_time2 - GetSecs()))
      # Uue the vbl from the first screen
      #vbl = Screen('Flip', wins_ptrs[0], next_frame_time)
      vbl = wins_ptrs[0].flip()
      for cur_win_ptr in wins_ptrs[1:]:
        cur_win_ptr.waitBlanking = False
        cur_win_ptr.flip()
        cur_win_ptr.waitBlanking = True
      #next_frame_time2 = GetSecs() + ifi
      # disp('Flipping took: ' + string(toc))
      already_cleared = False
    elif cur_cmd == 1 or (cur_cmd == 2 and not already_loaded):
      if not already_loaded:
        _, drawParams = loadSerializedData(m, 4)
        stim_type = drawParams.stimType
        if not already_cleared or stim_type != last_stim_type:
          # Disable anti-aliasing for dots initially
          GL.glDisable(GL.GL_POINT_SMOOTH)
          print('Clearing late load or stimulus type changed')
          # Clear first any previously drawn buffer by drawing a rect
          if stim_type == DrawStimType.RDK:
            bkg_clr = BLACK_COLOR
          else:
            bkg_clr = GRAY_COLOR

          for cur_win_ptr, cur_fill_rect in zip(wins_ptrs, fill_rects):
            #Screen('FillRect', cur_win_ptr, bkg_clr)
            #Screen('FillRect', cur_win_ptr, BLACK_COLOR, photo_diode_box)
            #Screen('Flip', cur_win_ptr, 0, 0, DONT_SYNC)
            cur_fill_rect.draw()
            cur_win_ptr.waitBlanking = False
            cur_win_ptr.flip(clearBuffer=False)
            cur_win_ptr.waitBlanking = True
          already_cleared = True
        # tic
        already_loaded = True
        already_stopped = False
        alphaBlendUsed = False
        vbl = 0 # Draw the frame asap once we are told
        if stim_type == DrawStimType.RDK:
          for cur_rect, cur_box in zip(fill_rects, photo_diode_boxes):
            cur_rect.setFillColor(BLACK_COLOR)
            cur_rect.setLineColor(BLACK_COLOR)
            cur_box.setFillColor(GRAY_COLOR)
            cur_box.setLineColor(GRAY_COLOR)
          if CIRCLE_RDK:
            field_area = np.pi*((drawParams.apertureSizeWidth/2)*
                                (drawParams.apertureSizeHeight/2))
          else:
            field_area = drawParams.apertureSizeWidth * \
                         drawParams.apertureSizeHeight
          # Calculate the size of a dot in pixel
          #dot_size_px = angle2pix(drawParams.screenWidthCm,
          #     winsRect[2], drawParams.screenDistCm, drawParams.dotSizeInDegs)
          from psychopy.tools.monitorunittools import deg2pix
          monitor.setDistance(drawParams.screenDistCm)
          dot_size_px = deg2pix(drawParams.dotSizeInDegs, monitor=monitor)
          print("DitsizePx:", dot_size_px)
          #if dot_size_px > 20
          #   disp('Reducing point size to max supported 20 from: ' +
          #        string(dot_size_pix))
          #   dot_size_px = 20
          #end
          dot_type = 1
          if dot_size_px > max_smooth_point_size:
            dot_type = 3
          scaled_draw_ratio = drawParams.drawRatio / dot_size_px
          nDots = np.around(field_area * scaled_draw_ratio)

          # First we'll calculate the left, right top and bottom of the
          # aperture (in degrees)
          # Apreture size between 0 and 1
          drawParams.apertureSizeWidth = 0.5
          drawParams.apertureSizeHeight = 0.5
          #aperture_size_width_pix = drawParams.apertureSizeWidth * win_size[0]
          #aperture_size_height_pix = drawParams.apertureSizeHeight * win_size[1]

          # We need to multiple by 2 to normalize 0:2 to -1:1 then divide by 2,
          # So basically we will just use the apertureSize as is.
          #centerX_pix = (drawParams.centerX * win_size[0]/2) + win_size[0]/2
          #centerY_pix = (drawParams.centerY * win_size[1]/2) + win_size[1]/2
          l =  drawParams.centerX - drawParams.apertureSizeWidth/2
          r =  drawParams.centerX + drawParams.apertureSizeWidth/2
          b =  drawParams.centerX - drawParams.apertureSizeHeight/2
          t =  drawParams.centerX + drawParams.apertureSizeHeight/2
          print(f"l: {l} - r: {r} - b: {b} - t: {t}")

          # Calculate ratio of incoherent for each direction so can use it later
          # to know how many dots should be per each direction. The ratio is
          # equal to the total incoherence divide by the number of directions
          # minus one. A coherence of zero has equal opportunity in all
          # directions, and thus the main direction ratio is the normal coherence
          # plus the its share of random incoherence.
          directionIncoherence = (1-drawParams.coherence)/len(directions)
          directionsRatios[:] = directionIncoherence
          directionsRatios[directions == drawParams.mainDirection] += \
                                                            drawParams.coherence
          # Round the number of dots that we have such that we get whole number
          # for each direction
          direction_ndots = np.rint(directionsRatios * nDots).astype(np.int)
          # Re-evaluate the number of dots. Convert to int and create as an
          # array so we can pass it as a list.
          nDots = np.int(direction_ndots.sum(),)
          # Convert lifetime to number of frames
          lifetime = np.ceil(drawParams.dotLifetimeSecs * frame_rate)
          # Each dot will have a integer value 'life' which is how many frames the
          # dot has been going.  The starting 'life' of each dot will be a random
          # number between 0 and dotsParams.lifetime-1 so that they don't all 'die' on the
          # same frame:
          dots_life = np.ceil(rnd_gen.random(nDots)*lifetime)
          # The distance traveled by a dot (in degrees) is the speed (degrees/second)
          # divided by the frame rate (frames/second). The units cancel, leaving
          # degrees/frame which makes sense. Basic trigonometry (sines and cosines)
          # allows us to determine how much the changes in the x and y position.
          #dx = drawParams.dotSpeed*np.sin(directions*np.pi/180)/frame_rate
          #dy = -drawParams.dotSpeed*np.cos(directions*np.pi/180)/frame_rate
          from psychopy.tools.monitorunittools import deg2pix
          dot_speed_norm = deg2pix(drawParams.dotSpeed, monitor)/win_size
          print("Dot speed pix:", dot_speed_norm)
          dxy[:,0] = dot_speed_norm[0]*np.sin(directions*np.pi/180)/frame_rate
          dxy[:,1] = -dot_speed_norm[1]*np.cos(directions*np.pi/180)/frame_rate
          #print("Dxy:", dxy)
          # Create all the dots in random starting positions
          #x = (rnd_gen.random(nDots_tup)-.5) * \
          #     drawParams.apertureSizeWidth + drawParams.centerX
          #y = (rnd_gen.random(nDots_tup)-.5) * \
          #     drawParams.apertureSizeHeight + drawParams.centerY
          # Take a slice of the original array, Second dimension has length of 2
          # for x and y
          dots_arr = dots_arr_buf[:nDots, :]
          print("nDots", nDots, "Dots arr shape:", dots_arr.shape)
          # Set between -0.5 to +0.5
          dots_arr = rnd_gen.random(dots_arr.shape, out=dots_arr) - 0.5
          dots_arr[:,0] *= drawParams.apertureSizeWidth + drawParams.centerX
          dots_arr[:,1] *= drawParams.apertureSizeHeight + drawParams.centerY

          # Next part is adapted from Psychtoolbox
          # dot_type = 3
          if dot_type in (1, 2):
            # Psychtoolbox: A dot type of 2 requests highest quality point smoothing
            GL.glEnable(GL.GL_POINT_SMOOTH)
            GL.glHint(GL.GL_POINT_SMOOTH_HINT,
                      GL.GL_NICEST if dot_type == 2 else GL.GL_DONT_CARE)
          else:
            if not attempted_gen_shaders:
              PsychtoolBox_COMPILE = True
              if PsychtoolBox_COMPILE:
                smooth_point_shader = CreateGLSLProgram(
                      PointSmoothFragmentShaderSrc, PointSmoothVertexShaderSrc,
                      debug=True)
              else:
                from OpenGL.GL.shaders import compileProgram, compileShader
                smooth_point_shader = compileProgram(
                            compileShader(PointSmoothVertexShaderSrc,
                                          GL.GL_VERTEX_SHADER),
                            compileShader(PointSmoothFragmentShaderSrc,
                                          GL.GL_FRAGMENT_SHADER))
              print("Shaders:", smooth_point_shader)
              attempted_gen_shaders = True
            if smooth_point_shader:
              GL.glUseProgram(smooth_point_shader)
              # ^ Or we can use SetShader(smooth_point_shader)
              GL.glActiveTexture(GL.GL_TEXTURE1)
              GL.glTexEnvi(GL.GL_POINT_SPRITE, GL.GL_COORD_REPLACE, GL.GL_TRUE)
              GL.glActiveTexture(GL.GL_TEXTURE0)
              GL.glEnable(GL.GL_POINT_SPRITE)
              # Tell shader from where to get its color information: Unclamped
              # high precision colors from texture coordinate set 0, or regular
              # colors from vertex color attribute?
              DefaultDrawShader = 0 # 1 or 0, zero by default
              GL.glUniform1i(GL.glGetUniformLocation(smooth_point_shader,
                                                     b"useUnclampedFragColor"),
                             DefaultDrawShader)
              # Tell shader if it should shade smooth round dots, or square dots
              GL.glUniform1i(GL.glGetUniformLocation(smooth_point_shader,
                                                      b"drawRoundDots"),
                              1 if dot_type == 3 else 0)
              # Tell shader about current point size in pointSize uniform:
              GL.glEnable(GL.GL_PROGRAM_POINT_SIZE)
        elif stim_type == DrawStimType.StaticGratings:
          for cur_rect, cur_box in zip(fill_rects, photo_diode_boxes):
            cur_rect.setFillColor(GRAY_COLOR)
            cur_rect.setLineColor(GRAY_COLOR)
            cur_box.setFillColor(BLACK_COLOR)
            cur_box.setLineColor(BLACK_COLOR)
          #myGrat = visual.GratingStim(tex='sin', mask='circle')  # circular grating
          # drawParams.gaborSizeFactor = 2
          # drawParams.gratingOrientation = 45
          # drawParams.cyclesPerSecondDrift = 5
          # drawParams.gaussianFilterRatio = 4
          # drawParams.numCycles = 0.1
          drawParams.gaborSizeFactor *= 2 # User scale is between zero and 1
          gratings = []
          from psychopy.tools.monitorunittools import deg2pix
          drawParams.screenDistCm = 30 # TODO: Add this
          monitor.setDistance(drawParams.screenDistCm)
          pixs_per_deg = deg2pix(1, monitor=monitor)
          # print("pixs_per_deg:", pixs_per_deg)
          for cur_win_ptr in wins_ptrs:
            cur_grating = visual.GratingStim(
                            cur_win_ptr,
                            tex='sin',
                            units="norm",
                            size=drawParams.gaborSizeFactor,
                            ori=drawParams.gratingOrientation,
                            phase=drawParams.phase/360,
                            sf=drawParams.numCycles,
                            mask='gauss',
                            maskParams={"sd":drawParams.gaussianFilterRatio})
            # Make it cycles per degree
            gabor_size = win_size * drawParams.gaborSizeFactor
            # print("Gabor size:", gabor_size,
            #       "- internal size:", cur_grating.size)
            gabor_degrees = gabor_size/pixs_per_deg
            # print("Gabor degrees:", gabor_degrees)
            cycles_per_deg = gabor_degrees * drawParams.numCycles
            # print("Cycles per deg:", cycles_per_deg)
            cur_grating.sf = cycles_per_deg
            gratings.append(cur_grating)
          shift_per_frame = drawParams.cyclesPerSecondDrift/frame_rate

        last_stim_type = stim_type
        for cur_box in photo_diode_boxes:
          cur_box.draw()
      else:
          time.sleep(0.005) # Wait for the run command
          continue
    elif cur_cmd == 0: # stop running
      if not already_stopped:
        already_stopped = True
        already_loaded = False
        for cur_win_ptr, cur_fill_rect in zip(wins_ptrs, fill_rects):
          cur_fill_rect.draw()
          cur_win_ptr.waitBlanking = False
          cur_win_ptr.flip(clearBuffer=False)
          cur_win_ptr.waitBlanking = True

        # Re-evaluate refresh rate in case it got slower
        # ifi = Screen('GetFlipInterval', cur_win_ptr)
        # frame_rate = 1/ifi
        #Priority(0)
        already_cleared = True
      else:
        time.sleep(0.01)
      continue
    else:
      print('Unexpected command received:', cur_cmd)
      continue

    if stim_type == DrawStimType.RDK:
      # tic
      #goodDots = \
      #    (x-drawParams.centerX)**2/(drawParams.apertureSizeWidth/2)**2 + \
      #    (y-drawParams.centerY)**2/(drawParams.apertureSizeHeight/2)**2 < 1
      if CIRCLE_RDK:
        good_dots = \
          (dots_arr[:,0]-drawParams.centerX)**2/(drawParams.apertureSizeWidth/2)**2 + \
          (dots_arr[:,1]-drawParams.centerY)**2/(drawParams.apertureSizeHeight/2)**2 < 1
        #convert from degrees to screen pixels
        #pixpos.x = angle2pix(drawParams.screenWidthCm, winsRect(2),
        #                     drawParams.screenDistCm, x) + winsRect(2)/2
        #pixpos.y = angle2pix(drawParams.screenWidthCm, winsRect(2),
        #                     drawParams.screenDistCm, y) + winsRect(3)/2
        pixpos = (dots_arr-0.5) * win_size + win_size/2
        # disp('Pre-drawing took: ' + string(toc))
        # tic
        good_dots_pix = pixpos[good_dots]
      else:
        good_dots_pix = (dots_arr-0.5) * win_size + win_size/2

      #print("Good dots:", good_dots_pix)
      for cur_win_ptr in wins_ptrs:
        dotsDraw(cur_win_ptr, good_dots_pix, dot_size_px)
        #Screen('DrawDots', cur_win_ptr,
        #    (xGoodDotsPix, yGoodDotsPix), dot_size_px, WHITE_COLOR, (0,0),
        #     dot_type)
      #Screen('DrawingFinished', window)
      #disp('Drawing took: ' + string(toc))
      # tic

      firstIdx = 0
      lastIdx = 0
      for directionIdx in range(len(directions)):
        lastIdx = lastIdx + direction_ndots[directionIdx]
        #update the dot position
        #x[firstIdx:lastIdx] = x[firstIdx:lastIdx] + dx[directionIdx]
        #y[firstIdx:lastIdx] = y[firstIdx:lastIdx] + dy[directionIdx]
        dots_arr[firstIdx:lastIdx] += dxy[directionIdx]
        firstIdx = lastIdx

      #move the dots that are outside the aperture back one aperture
      #width.
      #x[x<l] = x[x<l] + drawParams.apertureSizeWidth
      #x[x>r] = x[x>r] - drawParams.apertureSizeWidth
      #y[y<b] = y[y<b] + drawParams.apertureSizeHeight
      #y[y>t] = y[y>t] - drawParams.apertureSizeHeight
      dots_arr[dots_arr[:,0]<l,0] += drawParams.apertureSizeWidth
      dots_arr[dots_arr[:,0]>r,0] -= drawParams.apertureSizeWidth
      dots_arr[dots_arr[:,1]<b,1] += drawParams.apertureSizeHeight
      dots_arr[dots_arr[:,1]>t,1] -= drawParams.apertureSizeHeight

      #increment the 'life' of each dot
      dots_life = dots_life + 1

      #find the 'dead' dots
      dead_dots_idxs = np.where((dots_life % lifetime) == 0)[0]
      # print("Dead dots:", dots_arr[dead_dots_idxs])
      #replace the positions of the dead dots to a random location
      #x[deadDots] = (rnd_gen.random(1, sum(deadDots))-.5) * \
      #               drawParams.apertureSizeWidth + drawParams.centerX
      #y[deadDots] = (rand(1, sum(deadDots))-.5) * \
      #               drawParams.apertureSizeHeight + drawParams.centerY
      # Used dots from the back of the buffer
      if dead_dots_idxs.shape[0]:
        dead_dots = dots_arr_buf[-dead_dots_idxs.shape[0]:,:]
        #print("Dead dots:", dead_dots)
        #print("Dead dots life:", dots_life[dead_dots_idxs])
        dead_dots = rnd_gen.random(dead_dots.shape, out=dead_dots) - 0.5
        dead_dots[:,0] *= drawParams.apertureSizeWidth + drawParams.centerX
        dead_dots[:,1] *= drawParams.apertureSizeHeight + drawParams.centerY
        #print("new replacing dots:", dead_dots)
        dots_arr[dead_dots_idxs] = dead_dots # Assign back to original array
        #print("Deda dots idxss:", dead_dots_idxs)
        dots_life[dead_dots_idxs] = 1
    else: # Static and Moving Grating
      # Shift the grating by "shiftperframe" pixels per frame:
      # the mod'ulo operation makes sure that our "aperture" will snap
      # back to the beginning of the grating, once the border is reached.
      # Fractional values of 'xoffset' are fine here. The GPU will
      # perform proper interpolation of color values in the grating
      # texture image to draw a grating that corresponds as closely as
      # technical possible to that fractional 'xoffset'. GPU's use
      # bilinear interpolation whose accuracy depends on the GPU at hand.
      # Consumer ATI hardware usually resolves 1/64 of a pixel, whereas
      # consumer NVidia hardware usually resolves 1/256 of a pixel. You
      # can run the script "DriftTexturePrecisionTest" to test your
      # hardware...
      ## xOffset = mod(offsetIndex*shiftPerFrame, pixel_per_cycle)
      ## offsetIndex = offsetIndex + 1
      # Define shifted srcRect that cuts out the properly shifted
      # rectangular area from the texture: We cut out the range 0 to
      # visiblesize in the vertical direction although the texture is
      # only 1 pixel in height! This works because the hardware will
      # automatically replicate pixels in one dimension if we exceed the
      # real borders of the stored texture. This allows us to save
      # storage space here, as our 2-D grating is essentially only
      # defined in 1-D:
      #srcRect = (xOffset, 0, (xOffset+grating_dim_pix), grating_dim_pix)
      # for cur_win_ptr in wins_ptrs:
      #   # Draw grating texture, rotated by "orientation":
      #   Screen('DrawTexture', cur_win_ptr, gratingTex, srcRect, dstRect,
      #          gratingOrientation)
      #   if drawParams.gaussianFilterRatio > 0:
      #     # Draw gaussian mask over grating:
      #     Screen('DrawTexture', cur_win_ptr, maskTex,
      #            (0, 0, grating_dim_pix, gratingDimPx), dstRect,
      #            gratingOrientation)
      [cur_rect.draw() for cur_rect in fill_rects]
      for grating in gratings:
        grating.draw()
        grating.phase = (((grating.phase + shift_per_frame)*100)%100)/100
        # print("Grating.phase:", grating.phase)

    #for cur_win_ptr in wins_ptrs:
    #  Screen('FillRect', cur_win_ptr, WHITE_COLOR, photo_diode_box)
    [box.draw() for box in photo_diode_boxes]
    next_frame_time = vbl + (0.5*ifi)
    #print("Next frame time:", next_frame_time)
    #disp('Post draw took: ' + string(toc))
    #cur_cmd = 2

  #Priority(0)

# Modified from Psychopy's DotsStim.Draw()
import ctypes
import pyglet
pyglet.options['debug_gl'] = True # TODO: Change back to False
GL = pyglet.gl
def dotsDraw(win, dots, dot_size_px):
  win._setCurrent()
  GL.glPushMatrix()  # push before drawing, pop after
  # draw the dots
  win.setScale('pix')
  GL.glPointSize(dot_size_px)

  #glGetFloatv(GL_POINT_SIZE_RANGE, (GLfloat*) &pointsizerange)

  # load Null textures into multitexteureARB - they modulate with
  # glColor
  # GL.glActiveTexture(GL.GL_TEXTURE0)
  # GL.glEnable(GL.GL_TEXTURE_2D)
  # GL.glBindTexture(GL.GL_TEXTURE_2D, 0)
  # GL.glActiveTexture(GL.GL_TEXTURE1)
  # GL.glEnable(GL.GL_TEXTURE_2D)
  # GL.glBindTexture(GL.GL_TEXTURE_2D, 0)
  GL.glVertexPointer(2, GL.GL_DOUBLE, 0, dots.ctypes.data)
  #desiredRGB = self._getDesiredRGB(self.rgb, self.colorSpace,
  #                                  self.contrast)
  #GL.glColor4f(desiredRGB[0], desiredRGB[1], desiredRGB[2],
  #              self.opacity)
  GL.glColor4f(1, 1, 1, 1) # White (r, g, b) at full opacity
  GL.glEnableClientState(GL.GL_VERTEX_ARRAY)
  GL.glDrawArrays(GL.GL_POINTS, 0, dots.shape[0])
  GL.glDisableClientState(GL.GL_VERTEX_ARRAY)
  # GL.glVertexPointer(2, GL.GL_DOUBLE, 0, 0) # From Psychopy
  GL.glPopMatrix()


import ctypes
# Copied from PsychtoolBox
PointSmoothFragmentShaderSrc =b"""
#version 120
uniform int drawRoundDots;
varying vec4 unclampedFragColor;
varying float pointSize;

void main()
{
    /* Non-round, aliased square dots requested? */
    if (drawRoundDots == 0) {
       /* Yes. Simply passthrough unclamped color and be done: */
       gl_FragColor = unclampedFragColor;
       return;
    }

    /* Passthrough RGB color values: */
    gl_FragColor.rgb = unclampedFragColor.rgb;

    /* Adapt alpha value dependent on relative radius of the fragment within a dot:   */
    /* This for point smoothing on GPU's that don't support this themselves.          */
    /* Points on the border of the dot, at [radius - 0.5 ; radius + 0.5] pixels, will */
    /* get their alpha value reduced from 1.0 * alpha to 0.0, so they completely      */
    /* disappear over a distance of 1 pixel distance unit. The - 1.0 subtraction      */
    /* in clamp() accounts for the fact that pointSize is 2.0 pixels larger than user */
    /* code requested. This 1 pixel padding around true size avoids cutoff artifacts. */
    float r = length(gl_TexCoord[1].st - vec2(0.5, 0.5)) * pointSize;
    r = 1.0 - clamp(r - (0.5 * pointSize - 1.0 - 0.5), 0.0, 1.0);
    gl_FragColor.a = unclampedFragColor.a * r;
    if (r <= 0.0)
        discard;
}
"""

PointSmoothVertexShaderSrc = b"""
#version 120
/* Vertex shader: Emulates fixed function pipeline, but in HDR color mode passes    */
/* gl_MultiTexCoord0 as varying unclampedFragColor to circumvent vertex color       */
/* clamping on gfx-hardware / OS combos that don't support unclamped operation:     */
/* PTBs color handling is expected to pass the vertex color in gl_MultiTexCoord0    */
/* for unclamped drawing for this reason in unclamped color mode. gl_MultiTexCoord2 */
/* delivers individual point size (diameter) information for each point.            */

uniform int useUnclampedFragColor;
varying float pointSize;
varying vec4 unclampedFragColor;

void main()
{
    if (useUnclampedFragColor > 0) {
       /* Simply copy input unclamped RGBA pixel color into output varying color: */
       unclampedFragColor = gl_MultiTexCoord0;
    }
    else {
       /* Simply copy regular RGBA pixel color into output varying color: */
       unclampedFragColor = gl_Color;
    }

    /* Output position is the same as fixed function pipeline: */
    gl_Position = ftransform();

    /* Point size comes via texture coordinate set 2: Make diameter 2 pixels bigger    */
    /* than requested, to have some 1 pixel security margin around the dot, to avoid   */
    /* cutoff artifacts for the rendered point-sprite quad. Compensate in frag-shader. */
    pointSize = gl_MultiTexCoord2[0] + 2.0;
    gl_PointSize = pointSize;
}
"""


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

import time
_TIC = None
def tic():
  global _TIC
  _TIC = time.time()

def toc():
  return time.time() - _TIC


if __name__ == "__main__":
  drawDots()
