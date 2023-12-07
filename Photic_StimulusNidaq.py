# imports
from psychopy import visual, core
import numpy
import nidaqmx
from nidaqmx.constants import LineGrouping

# define stim parameters in frames based on framerate as according to 120Hz monitor:
stim_lengths = {
    1: {'frames_on': 2, 'frames_off': 118, 'repeats': 30},
    2: {'frames_on': 2, 'frames_off': 58, 'repeats': 60},
    4: {'frames_on': 2, 'frames_off': 28, 'repeats': 120},
    6: {'frames_on': 2, 'frames_off': 18, 'repeats': 180},
    8: {'frames_on': 2, 'frames_off': 15, 'repeats': 240},
    10: {'frames_on': 2, 'frames_off': 10, 'repeats': 300},
    12: {'frames_on': 2, 'frames_off': 8, 'repeats': 360},
    15: {'frames_on': 2, 'frames_off': 6, 'repeats': 450},
    20: {'frames_on': 2, 'frames_off': 4, 'repeats': 600},
    24: {'frames_on': 2, 'frames_off': 3, 'repeats': 720},
}

# create your list of stimuli based on frequencies and durations
stimList = []
for freq, durations in stim_lengths.items():
    code = numpy.zeros(7, dtype=bool)
    stimList.extend([{'frames_on': durations['frames_on'], 'frames_off': durations['frames_off'], 'TTL': code, 'frequency': freq}] * durations['repeats'])

# Setup the Window
win = visual.Window(
    monitor="testMonitor",
    fullscr=True,
    size=(2560, 1440),  # Set the size to match your screen resolution
    winType='pyglet',
    allowGUI=False,
    allowStencil=False,
    color=[0, 0, 0],
    colorSpace='rgb',
    blendMode='avg',
    useFBO=True,
)

# create box for diode
flipbox = visual.Rect(win, units='norm', width=0.5, height=0.5, lineColor='black', fillColor='black', size=0.2, lineColorSpace='rgb', fillColorSpace='rgb', pos=(1, -1))
flopbox = visual.Rect(win, units='norm', width=0.5, height=0.5, lineColor='white', fillColor='white', size=0.2, lineColorSpace='rgb', fillColorSpace='rgb', pos=(1, -1))

# run stims
for i, thisTrial in enumerate(stimList):
    # Check for escape key press
    keys = event.getKeys()
    if 'escape' in keys:
        print("Escape key pressed. Exiting the experiment.")
        break
    
    # create stimuli
    frames_on = thisTrial['frames_on']
    frames_off = thisTrial['frames_off']

    # create a rectangular stimulus (white or black) covering the entire screen
    stim_on_color = 'white'
    stim_on = visual.Rect(win, units='norm', width=2, height=2, fillColor=stim_on_color, lineColor=stim_on_color, pos=(0, 0))

    stim_off_color = 'black'
    stim_off = visual.Rect(win, units='norm', width=2, height=2, fillColor=stim_off_color, lineColor=stim_off_color, pos=(0, 0))

    # draw flipbox and flopbox
    win.flip()

    print(f"Stimulus {i + 1}: {frames_on} ms ON, {frames_off} ms OFF, Frequency: {thisTrial['frequency']} Hz")

    # run stims
    for _ in range(frames_on):
        stim_on.draw()
        flipbox.draw()
        win.flip()

    for _ in range(frames_off):
        stim_off.draw()
        flopbox.draw()
        win.flip()

    # TTL for stim
    with nidaqmx.Task() as task:
        task.do_channels.add_do_chan('Dev1/port0/line0:6', line_grouping=LineGrouping.CHAN_PER_LINE)
        task.write(thisTrial['TTL'], auto_start=True)

    # send low
    with nidaqmx.Task() as task:
        task.do_channels.add_do_chan(
            'Dev1/port0/line0:6', 
            line_grouping=LineGrouping.CHAN_PER_LINE)
        task.write([False, False, False, False, False, False, False], auto_start=True)

    # pause for 5 seconds after each change in frequency
    if i + 1 < len(stimList) and thisTrial['frequency'] != stimList[i + 1]['frequency']:
        core.wait(5.0)

# close the window after all trials
win.close()
core.quit()