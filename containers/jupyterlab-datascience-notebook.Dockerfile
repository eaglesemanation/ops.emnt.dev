FROM quay.io/jupyter/datascience-notebook:python-3.11.10

RUN pip install --no-cache-dir \
        # Visualisation
        hvplot panel jupyter_bokeh shapely geoviews \
        # Working with maps
        osmnx geopandas networkx \
        # Markdown parser
        jupyterlab_myst myst_parser \
        # Panel UI support
        jupyter-server-proxy \
        # LaTeX rendering
        jupyterlab-mathjax2 \
        # Collaborative editing
        jupyter-collaboration \
        # Autocomplete support
        jupyterlab-lsp 'python-lsp-server[all]' \
        # Editing CSV directly from UI
        jupyterlab-spreadsheet-editor

# Symlink for LSP to properly work with system wide packages
RUN ln -s / /home/jovyan/.lsp_symlink

LABEL org.opencontainers.image.authors="Vladimir Romashchenko <eaglesemanation@gmail.com>"
LABEL org.opencontainers.image.source="https://github.com/eaglesemanation/ops.emnt.dev"
LABEL org.opencontainers.image.licenses="BSD-3-Clause"
