#!/bin/bash --login

#SBATCH --nodes=5
#SBATCH --time=2:00:00
#SBATCH --export=NONE
#SBATCH --partition=debugq --time=01:00:00 --nodes=1

module swap PrgEnv-cray/6.0.4 PrgEnv-gnu
module load gromacs/2020.4

srun --export=all -n 48 gmx pdb2gmx -f (filename).pbd -o (desiredfilename).gro -water spce                              # changes pdb file to gro file. Generates topology and position restraints (forcefield).
srun --export=all -n 48 gmx editconf -f (desiredfilename).gro -o (filename)box.gro -c -d 1.0 -bt cubic                  # creates a box for the system
srun --export=all -n 48 gmx solvate -cp box.gro -cs spc216.gro -o (filename)solv.gro -p topol.top                       # solvates the box with water          
srun --export=all -n 48 gmx grompp -f ions.mdp -c (filename)solv.gro -p topol.top -o ions.tpr                           # adds ions onto the system to neutralise charges
srun --export=all -n 48 gmx genion -s ion.tpr -o (filename)solv_ions.gro -p topol.top -pname NA -nname CL -neutral
srun --export=all -n 48 gmx grompp -f minim.mdp -c (filename)solv_ions.gro -p topol.top -o em.tpr -maxwarn 1            # energy minimisation 
srun --export=all --mpi=pmi2 -n 120 -N 5 mdrun_mpi -v -deffnm em
srun --export=all -n 120 gmx grompp -f nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr -maxwarn 1                   # equilibration with constant number of particles, volume, and temperature (NVT)
srun --export=all --mpi=pmi2 -n 120 -N 5 mdrun_mpi -deffnm nvt
srun --export=all -n 48 gmx grompp -f npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr -maxwarn 1       # equilibration with number of particles, pressure, and temperature (NPT)
srun --export=all --mpi=pmi2 -n 120 -N 5 mdrun_mpi -deffnm npt
srun --export=all -n 48 gmx grompp -f md.mdp -c npt.gro -t npt.cpt -p topol.top -o fullmd.tpr -maxwarn 1                # Integrating Newton’s equations of motion
srun --export=all --mpi=pmi2 -n 120 -N 5 mdrun_mpi -deffnm fullmd
echo 1 0 | srun --export=all -n 1 gmx trjconv -s fullmd.tpr -f fullmd.xtc -o fullmdvis.xtc -pbc mol -center             # centre box around the protein and keep molecules that drift across the periodic boundaries whole
echo 1 1 | srun --export=all -n 1 gmx trjconv -f fullmd.xtc -s fullmd.tpr -o proteinmd.xtc -pbc mol                     # isolate protein trajectory from solvent 
echo 1 1 | srun --export=all -n 1 gmx trjconv -f proteinmd.xtc -s fullmd.tpr -pbc mol -o proteinmd.gro -b 0             # isolate protein coordinates from solvent
srun --export=all -n 24 gmx trjconv -f mutantrbd.trr -o mutantrbd_fit.xtc                                               # convert trr file generated from VMD to xtc
srun --export=all -n 24 gmx filter -f mutantrbd_fit.xtc -nf 10 -all -ol filteredmutant.xtc                              # smooths out movement of protein over 10 frames
