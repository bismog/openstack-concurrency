#!/usr/bin/env python

import matplotlib as mpl
mpl.use('Agg')

import matplotlib.pyplot as plt
from matplotlib import colors
import random
import os

def get_random_color(pastel_factor = 0.5):
    return [(x+pastel_factor)/(1.0+pastel_factor) for x in [random.uniform(0,1.0) for i in [1,2,3]]]

def color_distance(c1,c2):
    return sum([abs(x[0]-x[1]) for x in zip(c1,c2)])

def generate_new_color(existing_colors,pastel_factor = 0.5):
    max_distance = None
    best_color = None
    for i in range(0,100):
        color = get_random_color(pastel_factor = pastel_factor)
        if not existing_colors:
            return color
        best_distance = min([color_distance(color,c) for c in existing_colors])
        if not max_distance or best_distance > max_distance:
            max_distance = best_distance
            best_color = color
    return best_color

ops = ("create", "stop", "start", "reboot", "delete")
def op_verify(op):
    return True if op in ops else False
    
# choose 20 random colours:
hex_ = []
mycolours = []
names = []
for i in range(20):
    mycolour = generate_new_color(mycolours,pastel_factor = 0.9)
    mycolours.append(mycolour)
    myhex = colors.rgb2hex(mycolour)
    hex_.append(myhex)
    names.append(myhex)

# Get data from files in directory /home/chml/perf/all_in_one
# In /home/chml/perf/all_in_one/, there were some directory named such as:
# create, stop, start, reboot, delete.
# All these files have same format as following:
# <operation> <instances> <time-consumption>
# What we need to do are:
# Get last two columns and draw graph via matplotlib.
all_data = {
    'create': [],
    'stop': [],
    'start': [],
    'reboot': [],
    'delete': []
}
data_path = "/home/chml/perf/all_in_one/"
for r,d,ff in os.walk(data_path):
    for f in ff:
        fn = '{}/{}'.format(r,f)
        try:
            with open(fn) as fd:
                data = fd.readlines()
                oit = data[0].split()
                # oit = data
                op = oit[0]
                # print("oit: %s" % oit)
                # print("op: %s" % oit[0])
                if not op_verify(op):
                    print("INFO: Unknown operation.")
                else:
                    all_data[op].append([oit[1], oit[2]])
        except IndexError,e:
            print("INFO: Found no instance number or time cost.")
            continue

for op in ops:
    plt.style.use('classic')
    # More style at: https://tonysyu.github.io/raw_content/matplotlib-style-gallery/gallery.html
    # plt.style.use('seaborn-pastel')
    fig = plt.figure()
    for data in all_data[op]:
        try:
            x = float(data[0])
            y = float(data[1])
            plt.scatter(x, y, color=random.choice(hex_))
        except ValueError,e:
            continue
    plt.xlabel('instances')
    plt.ylabel('time(sec)')
    plt.title('Concurrent %s instances' % op)
    png_name = '{}{}.png'.format("/home/chml/vm_perf_", op)
    fig.savefig(png_name)
