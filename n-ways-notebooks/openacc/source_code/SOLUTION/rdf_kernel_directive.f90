!/////////////////////////////////////////////////////////////////////////////////////////
!// Author: Manish Agarwal and Gourav Shrivastava, IIT Delhi
!/////////////////////////////////////////////////////////////////////////////////////////

! Copyright (c) 2021 NVIDIA Corporation. All rights reserved.
module readdata
contains

  subroutine readheader(unit_num, natoms, nframes)
    integer, intent(in) :: unit_num
    integer, intent(out) :: natoms, nframes
    real(4) :: dummyr
    integer(4) :: dummyi, nframes_4
    character(4) :: dummyc

    read(unit_num) dummyc, nframes_4, (dummyi, i=1, 8), dummyr, (dummyi, i=1, 9)
    read(unit_num) dummyi, dummyr, dummyr
    read(unit_num) natoms

    nframes = nframes_4

    return
  end subroutine readheader

  subroutine readdcd(unit_num, x, y, z, xbox, ybox, zbox, natoms, nframes)
    integer, intent(in) :: unit_num, natoms, nframes
    real(8), intent(out) :: xbox, ybox, zbox
    real(4), intent(out) :: x(:), y(:), z(:)
    real(8) :: d(6)
    integer :: i, j

    do i = 1, nframes
       read(unit_num) (d(j), j=1, 6)
       read(unit_num) (x((i - 1) * natoms + j), j = 1, natoms)
       read(unit_num) (y((i - 1) * natoms + j), j = 1, natoms)
       read(unit_num) (z((i - 1) * natoms + j), j = 1, natoms)
    end do

    xbox = d(1)
    ybox = d(3)
    zbox = d(6)

    return
  end subroutine readdcd

end module readdata

program rdf
  use readdata
  use nvtx
  implicit none
  integer :: n, i, j, iconf, ind
  integer :: natoms, nframes, nbin
  integer :: maxframes
  integer :: unit_num
  real(4), allocatable :: h_x(:)
  real(4), allocatable :: h_y(:)
  real(4), allocatable :: h_z(:)
  integer, allocatable :: h_g(:)
  real(8), allocatable :: g(:)
  real(8) :: dx, dy, dz
  real(8) :: xbox, ybox, zbox, box
  real(8) :: pi, rho, const, del
  real(8) :: r, gr, lngr, lngrbond, s2, s2bond
  real(8) :: rlower, rupper, nideal
  character(len=256) :: filename

  !*****************Input Details*********************************************
  parameter (maxframes = 10, nbin = 2000)
  filename = '../../_common/input/alk.traj.dcd'
  !***************************************************************************

  open(23, file='RDF.dat', status='unknown')
  open(24, file='Pair_entropy.dat', status='unknown')

  unit_num = 10
  open(unit_num, file = filename, status = 'old', form = 'unformatted')

  call readheader(unit_num, natoms, nframes)

  ! Limit the number of frames to 10.
  if (nframes .gt. maxframes) then
     nframes = maxframes
  end if

  allocate(h_x(nframes * natoms))
  allocate(h_y(nframes * natoms))
  allocate(h_z(nframes * natoms))
  allocate(h_g(nbin))
  h_g = 0

  !*****************Reading Coordinates***************************************
  call nvtxStartRange("Read File")
  call readdcd(unit_num, h_x, h_y, h_z, xbox, ybox, zbox, natoms, nframes)
  call nvtxEndRange
  !***************************************************************************

  close(unit_num)

  box = min(xbox, ybox)
  box = min(box, zbox)
  del = box / dble(2.0 * nbin)

  !******************This is where we will concentrate************************
  call nvtxStartRange("Pair Calculation")
  call pair_gpu(h_x, h_y, h_z, h_g, natoms, nframes, xbox, ybox, zbox, box, del)
  call nvtxEndRange
  !***************************************************************************

  pi = dacos(-1.0d0)
  rho = dble(natoms) / (xbox * ybox * zbox)
  const = (4.0d0 / 3.0d0) * pi * rho
  s2 = 0.00d0
  s2bond = 0.00d0
  allocate(g(nbin))

  !******************Calculate Entropy****************************************
  call nvtxStartRange("Entropy Calculation")
  do i = 1, nbin
     rlower = dble((i - 1) * del)
     rupper = rlower + del
     nideal = const * (rupper**3 - rlower**3)
     g(i) = dble(h_g(i)) / (dble(nframes) * dble(natoms) * nideal)
     r = dble(i - 1) * del
     write(23, *) dble(i - 0.5) * del, g(i)

     if (r < 2.0d0) then
        gr = 0.0
     else
        gr = g(i)
     end if

     if (gr < 1e-5) then
        lngr = 0.0
     else
        lngr = dlog(gr)
     end if

     if (g(i) < 1e-6) then
        lngrbond = 0.01d0
     else
        lngrbond = dlog(g(i))
     end if

     s2 = s2 - 2.0d0 * pi * rho * ((gr * lngr) - gr + 1) * del * r**2.0
     s2bond = s2bond - 2.0d0 * pi * rho * ((g(i) * lngrbond) - g(i) + 1) * del * r**2.0
  end do
  call nvtxEndRange
  !***************************************************************************

  !******************Write Output*********************************************
  write(24, '(A,F0.5)') "s2 value is ", s2
  write(24, '(A,F0.5)') "s2bond value is ", s2bond
  !***************************************************************************

  deallocate(h_x, h_y, h_z, h_g, g)
  close(23)
  close(24)

contains
  subroutine pair_gpu(d_x, d_y, d_z, d_g, natoms, nframes, xbox, ybox, zbox, box, del)
    implicit none
    integer, intent(in) :: natoms, nframes
    integer, intent(inout) :: d_g(:)
    real(4), intent(in) :: d_x(:), d_y(:), d_z(:)
    real(8), intent(in) :: xbox, ybox, zbox, box, del
    integer :: i, j, iconf, ind
    real(4) :: r, dx, dy, dz
    real(8) :: cut
    cut = dble(box * 0.5)

    do iconf = 1, nframes
       !$acc kernels loop independent
       do i = 1, natoms
          !$acc loop independent
          do j = 1, natoms
             dx = d_x((iconf - 1) * natoms + i) - d_x((iconf - 1) * natoms + j)
             dy = d_y((iconf - 1) * natoms + i) - d_y((iconf - 1) * natoms + j)
             dz = d_z((iconf - 1) * natoms + i) - d_z((iconf - 1) * natoms + j)

             dx = dx - nint(dx / xbox) * xbox
             dy = dy - nint(dy / ybox) * ybox
             dz = dz - nint(dz / zbox) * zbox

             r = sqrt(dx**2 + dy**2 + dz**2)
             if (r < cut) then
                ind = int(r / del) + 1
                !$acc atomic
                d_g(ind) = d_g(ind) + 1
             end if
          end do
       end do
       !$acc end kernels
    end do
  end subroutine pair_gpu

end program rdf
