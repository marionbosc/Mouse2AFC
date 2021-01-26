# -*- coding: utf-8 -*-
"""
Created on Mon Jan 13 17:58:21 2020

@author: lisak
"""

import dash
import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output

import pandas as pd
import analysis

external_stylesheets = ['https://codepen.io/chriddyp/pen/bWLwgP.css']

#df = pd.read_csv('Mock.csv', sep=';')
DATA_FILE=r"C:\Users\hatem\OneDrive\Documents\py_matlab\wfThy2_Mouse2AFC_Dec05_2019_Session1.mat"
import mat_reader
df = mat_reader.loadFiles(DATA_FILE)
#mice = df['Mouse'].unique()
mice_names = df.Name.unique()

plotter = analysis.Plotter(is_matplotlib=False)

app = dash.Dash(__name__, external_stylesheets=external_stylesheets)

sessions = df.groupby([df.Date,df.SessionNum])
earliest_session = df[df.Date == df.Date.min()]
earliest_session = earliest_session[earliest_session.SessionNum ==
                                    earliest_session.SessionNum.min()]
earliest_session = "{}_{}".format(earliest_session.Date.iloc[0],
                                  earliest_session.SessionNum.iloc[0])
latest_session = df[df.Date == df.Date.max()]
latest_session = latest_session[latest_session.SessionNum ==
                                latest_session.SessionNum.max()]
latest_session = "{}_{}".format(latest_session.Date.iloc[0],
                                latest_session.SessionNum.iloc[0])

app.layout = html.Div([
        html.Label('Mouse ID'),

        dcc.Dropdown(
                id = 'mouse-drop',
                options = [{'label': i, 'value': i} for i in mice_names],
                value = 'Fred'
                ),

        dcc.Graph(id='graph'),

        html.Label('Session'),

        dcc.Slider(
                id='session-slider',
                min=1,
                max=1,
                value=1,
                marks={1:"{}_{}".format(session_date, session_num)
                       for (session_date, session_num), session_df in sessions},
                step=None
                )
        ],
        style={'width': '50%'})

@app.callback(
    Output('graph', 'figure'),
    [Input('mouse-drop', 'value'),
     Input('session-slider', 'value')])



def update_graph(mouse_name, session_value):
    print("Update graph is called")
    _x = None
    _y = None
    _text = None
    _x_label = None
    _y_label = None
    _x_lims = None
    _y_lims = None
    def setXandY(x, y):
        nonlocal _x, _y
        _x, _y = x, y

    def setTraceName(text):
        nonlocal _text
        _text = text

    plotter.setPlotlyFunctions(setXandY, setTraceName=setTraceName)
    analysis.trialRate(df, plotter)


    return {
        'data': [dict(
            x=_x,
            y=_y,
            text=_text,
            mode='lines',
        )],

        'layout': dict(
                xaxis={'title': 'Coherence', 'range': [_x.min(), _x.max()]}, # Define range to avoid rescaling on every reload
                yaxis={'title': 'Av. Poke', 'range': [_y.min(), _y.max()]},
                margin={'l': 40, 'b': 40, 't': 10, 'r': 10},
                legend={'x': 0, 'y': 1},
                hovermode='closest'
        )
    }
    return result_str

def update_graph2(mouse_name, session_value):
    result_str = None

    dff = df[df['Session'] == session_value]
    #analysis.PerformanceOverTime(df, mouse_name, axes=assignResultStr)

    return {
        'data': [dict(
            x=dff[dff['Mouse'] == mouse_name]['Coherence'],
            y=dff[dff['Mouse'] == mouse_name]['Poke'],
            text=dff[dff['Mouse'] == mouse_name]['Mouse'],
            mode='lines',
            marker={
                'size': 15,
                'opacity': 0.5,
                'line': {'width': 0.5, 'color': 'white'}
            }
        )],

        'layout': dict(
                xaxis={'title': 'Coherence', 'range': [-100, 100]}, # Define range to avoid rescaling on every reload
                yaxis={'title': 'Av. Poke', 'range': [-100, 100]},
                margin={'l': 40, 'b': 40, 't': 10, 'r': 10},
                legend={'x': 0, 'y': 1},
                hovermode='closest'
        )
    }


if __name__ == '__main__':
    app.run_server(debug=True)



