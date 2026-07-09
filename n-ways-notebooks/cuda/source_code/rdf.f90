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

    read (unit_num) dummyc, nframes_4, (dummyi, i=1, 8), dummyr, (dummyi, i=1, 9)
    read (unit_num) dummyi, dummyr, dummyr
    read (unit_num) natoms

    nframes = nframes_4

    return
  end subroutine readheader

  subroutine readdcd(unit_num, x, y, z, xbox, ybox, zbox, natoms, nframes)
    implicit none
    integer, intent(in) :: unit_num, natoms, nframes
    real(8), intent(out) :: xbox, ybox, zbox
    real(4), intent(out) :: x(:), y(:), z(:)
    real(8) :: d(6)
    integer :: i, j

    do i = 1, nframes
      read (unit_num) (d(j), j=1, 6)
      read (unit_num) (x((i - 1)*natoms + j), j=1, natoms)
      read (unit_num) (y((i - 1)*natoms + j), j=1, natoms)
      read (unit_num) (z((i - 1)*natoms + j), j=1, natoms)
    end do

    xbox = d(1)
    ybox = d(3)
    zbox = d(6)

    return
  end subroutine readdcd

end module readdata

! Note: Subroutines for CUDA kernels cannot be in the main program and must
! be in a module
module pair_calculation
contains

  ! TODO: write CUDA syntax to make this subroutine global
  ! so it can be callable from the host (CPU)
  ???(???) subroutine pair_gpu(d_x, d_y, d_z, d_g, natoms, nframes, &
                                xbox, ybox, zbox, box, del)
    use cudafor ! Note: CUDA API
    implicit none
    ! Note: Scalar variables used on the GPU are given the "value" keyword
    integer, value, intent(in) :: natoms, nframes
    integer, intent(inout) :: d_g(:)
    real(4), intent(in) :: d_x(:), d_y(:), d_z(:)
    real(8), value, intent(in) :: xbox, ybox, zbox, box, del
    integer :: i, j, iconf, ind
    integer :: oldvalue ! Note: for CUDA atomic addition
    real(4) :: r, dx, dy, dz
    real(8), value :: cut
    cut = dble(box*0.5)
    ! TODO: Write indexing logic using threads and blocks
    ! Hint: As we assigned a 2d grid of blocks, id1 gets its values
    !       from the %x dim and id2 from the %y dim.
    i = ?
    j = ?

    do iconf = 1, nframes
      if (i .le. natoms .and. j .le. natoms) then
        dx = d_x((iconf - 1)*natoms + i) - d_x((iconf - 1)*natoms + j)
        dy = d_y((iconf - 1)*natoms + i) - d_y((iconf - 1)*natoms + j)
        dz = d_z((iconf - 1)*natoms + i) - d_z((iconf - 1)*natoms + j)

        dx = dx - nint(dx/xbox)*xbox
        dy = dy - nint(dy/ybox)*ybox
        dz = dz - nint(dz/zbox)*zbox

        r = sqrt(dx**2 + dy**2 + dz**2)
        if (r < cut) then
          ind = int(r/del) + 1
          ! Note: Using CUDA API atomic function attomicadd()
          oldvalue = atomicadd(d_g(ind), 1)
        end if
      end if
    end do
    return
  end subroutine pair_gpu

end module pair_calculation

program rdf
  use readdata
  use nvtx
  use pair_calculation ! Note: pair_gpu is now in a module
  use cudafor ! Note: CUDA API
  implicit none
  integer :: n, i, j, iconf, ind
  integer :: natoms, nframes, nbin
  integer :: maxframes
  integer :: unit_num
  integer :: istat
  type(dim3) :: nblock, nthreads
  ! TODO (only managed): Write CUDA syntax to manage the data
  real(4), allocatable :: h_x(:)
  real(4), allocatable :: h_y(:)
  real(4), allocatable :: h_z(:)
  integer, allocatable :: h_g(:)
  ! TODO (only managed): Remove unused device variables
  ! TODO (only unmanaged): Write CUDA syntax to create device (GPU) arrays
  real(4), ?, allocatable :: d_x(:)
  real(4), ?, allocatable :: d_y(:)
  real(4), ?, allocatable :: d_z(:)
  integer, ?, allocatable :: d_g(:)
  real(8), allocatable :: g(:)
  real(8) :: dx, dy, dz
  real(8) :: xbox, ybox, zbox, box
  real(8) :: pi, rho, const, del
  real(8) :: r, gr, lngr, lngrbond, s2, s2bond
  real(8) :: rlower, rupper, nideal
  character(len=256) :: filename

  !*****************Input Details*********************************************
  parameter(maxframes=10, nbin=2000)
  filename = '../../_common/input/alk.traj.dcd'
  !***************************************************************************

  open (23, file='RDF.dat', status='unknown')
  open (24, file='Pair_entropy.dat', status='unknown')

  unit_num = 10
  open (unit_num, file=filename, status='old', form='unformatted')

  call readheader(unit_num, natoms, nframes)

  ! Limit the number of frames to 10.
  if (nframes .gt. maxframes) then
    nframes = maxframes
  end if

  allocate (h_x(nframes*natoms))
  allocate (h_y(nframes*natoms))
  allocate (h_z(nframes*natoms))
  allocate (h_g(nbin))

  h_g = 0

  !*****************Reading Coordinates***************************************
  call nvtxStartRange("Read File")
  call readdcd(unit_num, h_x, h_y, h_z, xbox, ybox, zbox, natoms, nframes)
  call nvtxEndRange
  !***************************************************************************

  close (unit_num)

  box = min(xbox, ybox)
  box = min(box, zbox)
  del = box/dble(2.0*nbin)

  !******************This is where we will concentrate************************
  ! TODO (only unmanaged): Allocate memory for device (GPU)

  ! TODO (only unmanaged): Copy the required data from Host to Device before
  ! calculation on GPU using istat = cudaMemcpy(d_var, h_var, size);

  ! Note: Defines the number of threads per block and the number of blocks in
  ! the grid.  Here, we are using a 2D grid, where the total of nblock * nthreads
  ! in each dimension is natoms (or the closest multiple bigger than natoms).
  nthreads = dim3(16, 16, 1)
  nblock%x = (natoms + nthreads%x - 1)/nthreads%x
  nblock%y = (natoms + nthreads%y - 1)/nthreads%y
  nblock%z = 1

  call nvtxStartRange("Pair Calculation")
  ! TODO: Place nthreads and nblock in the correct order and
  ! fill in the correct variables
  call pair_gpu <<<?, ?>>> (?_x, ?_y, ?_z, ?_g, natoms, &
                            nframes, xbox, ybox, zbox, box, del)
  call nvtxEndRange

  ! Note: Syncing Host and Device
  istat = cudaDeviceSynchronize()

  ! TODO (only unmanaged): Copy the required data from Device to Host after
  ! calculation on GPU using istat = cudaMemcpy(h_var, d_var, size);

  !***************************************************************************

  pi = dacos(-1.0d0)
  rho = dble(natoms)/(xbox*ybox*zbox)
  const = (4.0d0/3.0d0)*pi*rho
  s2 = 0.00d0
  s2bond = 0.00d0
  allocate (g(nbin))

  !******************Calculate Entropy****************************************
  call nvtxStartRange("Entropy Calculation")
  do i = 1, nbin
    rlower = dble((i - 1)*del)
    rupper = rlower + del
    nideal = const*(rupper**3 - rlower**3)
    g(i) = dble(h_g(i))/(dble(nframes)*dble(natoms)*nideal)
    r = dble(i - 1)*del
    write (23, *) dble(i - 0.5)*del, g(i)

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

    s2 = s2 - 2.0d0*pi*rho*((gr*lngr) - gr + 1)*del*r**2.0
    s2bond = s2bond - 2.0d0*pi*rho*((g(i)*lngrbond) - g(i) + 1)*del*r**2.0
  end do
  call nvtxEndRange
  !***************************************************************************

  !******************Write Output*********************************************
  write (24, '(A,F0.5)') "s2 value is ", s2
  write (24, '(A,F0.5)') "s2bond value is ", s2bond
  !***************************************************************************

  deallocate (h_x, h_y, h_z, h_g, g)
  ! TODO (only unmanaged): Deallocate memory on Device (GPU)

  close (23)
  close (24)

end program rdf
