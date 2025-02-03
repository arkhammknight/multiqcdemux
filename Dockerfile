FROM rocker/tidyverse:latest

# Install system dependencies and R packages (as before)

# Set working directory
WORKDIR /usr/src/app

# Copy R script
COPY 2demux_ss_sinan.R /usr/src/app/

# Create input and Reports directories
RUN mkdir -p /usr/src/app/input /usr/src/app/Reports

# Make the R script executable
RUN chmod +x /usr/src/app/2demux_ss_sinan.R

# Set the command to run when the container starts
CMD ["Rscript", "/usr/src/app/2demux_ss_sinan.R"]