# -*- coding: utf-8 -*-
"""
Created on Sat Aug  6 17:51:48 2016

@author: mariapanteli
"""

import pandas
import numpy
from sklearn.metrics.pairwise import pairwise_distances
from mpl_toolkits.basemap import Basemap
import matplotlib.pyplot as plt
import matplotlib as MM
from shapely.geometry import Point, Polygon
import random
from bokeh.models import HoverTool, TapTool, CustomJS
from bokeh.plotting import figure, show, save, output_file, ColumnDataSource

def get_random_point_in_polygon(poly):
     (minx, miny, maxx, maxy) = poly.bounds
     while True:
         p = Point(random.uniform(minx, maxx), random.uniform(miny, maxy))
         if poly.contains(p):
             return p

# Load data
features = pandas.read_csv('data/features.csv', header=None, delimiter=' ').get_values()
n_samples = len(features)
df = pandas.read_csv('data/metadata.csv')
countries = numpy.array(df['Country'].get_values(), dtype=str)

dist_matrix = pairwise_distances(features, metric='mahalanobis')
neighbors = numpy.argsort(dist_matrix, axis=1)
neighbors = neighbors[:, 1:2]  # nearest neighbor, avoid seld-similarity

# country names, polygons
mm=Basemap()
mm.readshapefile("data/ne_110m_admin_0_countries", 'units')
pp_x = []
pp_y = []
countries_poly = []
for shape, info in zip(mm.units, mm.units_info):
    pp_x.append([ss[0] for ss in shape])
    pp_y.append([ss[1] for ss in shape])
    countries_poly.append(info['admin'])

# get coordinates of recording within the country polygons 
countries_pp = numpy.array(countries_poly, dtype=str)
data_x = []
data_y = []
for country in countries:
    poly_inds = numpy.where(countries_pp==country)[0]
    poly = mm.units[poly_inds[0]]
    if len(poly_inds)>1:
        # if many polys for country choose the largest one (ie most points)
        len_list = [len(pp_x[poly_ind]) for poly_ind in poly_inds]
        poly = mm.units[poly_inds[numpy.argmax(len_list)]]
    p = Polygon(poly)
    point_in_poly = get_random_point_in_polygon(p)
    data_x.append(point_in_poly.x)
    data_y.append(point_in_poly.y)

# create lines that link recordings with their closest neighbor
line_x = []
line_y = []
for i in range(n_samples):
    for neighbor in neighbors[i,:]:
        line_x.append([data_x[i], data_x[neighbor]])
        line_y.append([data_y[i], data_y[neighbor]])

# color by country 
classlabs = countries
classes = numpy.unique(classlabs)
colors = plt.cm.spectral(numpy.linspace(0, 1, len(classes)))
bokehcolors = [MM.colors.rgb2hex(cc) for cc in colors]
country_colors = [bokehcolors[numpy.where(classes==classlab)[0][0]] for classlab in classlabs]

# bokeh interactive plot
source = ColumnDataSource(data=dict(
        x=data_x,
        y=data_y,
        name=countries,
        info = [[df['Culture'].iloc[ind], df['Language'].iloc[ind], df['Genre_Album'].iloc[ind]] for ind in range(n_samples)],
        url=numpy.array(df['songurls_Album'].get_values(), dtype=str),
        color = country_colors
    ))
TOOLS="wheel_zoom,box_zoom,pan,reset,save,resize"
    
p = figure(tools=TOOLS, plot_width=1200, title="")
r1 = p.patches(pp_x, pp_y, fill_color='white', line_width=0.4, line_color='grey')
r2 = p.circle_cross('x','y', size=4, line_color=country_colors, source=source) 
r3 = p.multi_line(xs=line_x, ys=line_y, alpha=0.5, color='grey', line_width=0.2)

# some interactive functionality on mouse click and mouse over
callback = CustomJS(args=dict(r2=r2), code="""
        var inds = cb_obj.get('selected')['1d'].indices;
        var d1 = cb_obj.get('data');
        url = d1['url'][inds[0]];
        if (url){
            window.open(url);}""")
hover_tooltips = """
    <div>
        <div>
            <span style="font-size: 17px; font-weight: bold;">@name</span>
        </div>
        <div>
            <span style="font-size: 12px;">@info</span>
        </div>
    </div>
    """
p.add_tools(HoverTool(renderers=[r2], tooltips=hover_tooltips))
p.add_tools(TapTool(renderers=[r2], callback = callback))

# formatting
p.outline_line_color = None
p.grid.grid_line_color=None
p.axis.axis_line_color=None
p.axis.major_label_text_font_size='0pt'
p.axis.major_tick_line_color=None
p.axis.minor_tick_line_color=None

output_file('similarity_map.html')
show(p)