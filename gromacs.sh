#!/bin/bash --login

#SBATCH --nodes=5
#SBATCH --time=2:00:00
#SBATCH --export=NONE
#SBATCH --partition=debugq --time=01:00:00 --nodes=1

module swap PrgEnv-cray/6.0.4 PrgEnv-gnu
module load gromacs/2020.4

srun --export=all -n 48  gmx grompp -f minim.mdp -c muions.gro -p topol.top -o em.tpr -maxwarn 1
srun --export=all --mpi=pmi2 -n 120 -N 5 mdrun_mpi -v -deffnm em
srun --export=all -n 120 gmx grompp -f nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr -maxwarn 1
srun --export=all --mpi=pmi2 -n 120 -N 5 mdrun_mpi -deffnm nvt
srun --export=all -n 48 gmx grompp -f npt.mdp -c nvt.gro -r nvt.gro -t nvt.cpt -p topol.top -o npt.tpr -maxwarn 1
srun --export=all --mpi=pmi2 -n 120 -N 5 mdrun_mpi -deffnm npt
srun --export=all -n 48 gmx grompp -f md.mdp -c npt.gro -t npt.cpt -p topol.top -o fullmd.tpr -maxwarn 1
srun --export=all --mpi=pmi2 -n 120 -N 5 mdrun_mpi -deffnm fullmd
echo 1 0 | srun --export=all -n 1 gmx trjconv -s fullmd.tpr -f fullmd.xtc -o fullmdvis.xtc -pbc mol -center
echo 1 1 | srun --export=all -n 1 gmx trjconv -f fullmd.xtc -s fullmd.tpr -o proteinmd.xtc -pbc mol
echo 1 1 | srun --export=all -n 1 gmx trjconv -f proteinmd.xtc -s fullmd.tpr -pbc mol -o proteinmd.gro -b 0
