#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Nov 27 13:54:02 2018

@author: prubbens
"""
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns

df_E = pd.read_csv('data/CD/N_clusters_k=30_E.csv', index_col=0, header=0)
df_E.columns = ['Number of clusters']
df_E['Method'] = 'Euclidean'
df_dmlmj_cv = pd.read_csv('data/CD/N_clusters_k=30_CV.csv', index_col=0, header=0)

df_M = pd.DataFrame(np.diag(df_dmlmj_cv))
df_TM = []
for i in np.arange(0,df_dmlmj_cv.shape[0]): 
    for j in np.arange(0,df_dmlmj_cv.shape[1]): 
        if i != j: 
            df_TM.append(df_dmlmj_cv.iloc[i,j])
df_TM = pd.DataFrame(df_TM)

df_M.columns = ['Number of clusters']
df_M['Method'] = 'DMLMJ'
df_TM.columns = ['Number of clusters']
df_TM['Method'] = 'T-DMLMJ'
df_ = pd.concat([df_E, df_M, df_TM], axis=0)

g = sns.factorplot(x='Method',y='Number of clusters',data=df_, kind='box', height=5, aspect=0.75, sharey=True, palette='colorblind',linewidth=2)
g.set_titles(size=20)
#g.set_axis_labels('Type',r'$\rho_{s}$')
g.set_xlabels(fontsize=18)
g.set_ylabels(fontsize=18)
    #x_coord = [0,0,0,0]
    #y_coord = [0.7730,0.8123,0.7789,0.794]
    #for ax, x, y in zip(g.axes.flat, x_coord, y_coord):
    #    ax.plot([x,x+2], [y,y], linewidth=2, linestyle='--', c='gray')
plt.savefig('Number_of_clusters.png',bbox_inches='tight', dpi=500)

df_dmlmj_v = pd.DataFrame(pd.read_csv('data/CD/V_k=30_CV.csv', index_col=0, header=0).values.reshape(-1,1))
df_dmlmj_v.columns = ['V-measure']
df_dmlmj_v['Number of clusters'] = df_dmlmj_cv.values.reshape(-1,1)

sns.scatterplot(x='Number of clusters',y='V-measure', data=df_dmlmj_v)