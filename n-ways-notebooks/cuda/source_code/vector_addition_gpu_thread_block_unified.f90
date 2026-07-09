module kernel
contains

  ! CUDA kernel. Each thread takes care of one element of c
  attributes(global) subroutine device_add(n, a, b, c)
    integer, value  :: n
    integer, device :: a(n), b(n), c(n)
    integer :: idx

    ! Get our global thread ID
    idx = (blockidx%x - 1) * blockdim%x + threadidx%x
    c(idx) = a(idx) + b(idx)
  end subroutine device_add

  subroutine fill_array(n, data)
    integer :: n
    integer :: data(n)
    integer :: idx

    do idx = 1, n
       data(idx) = idx
    end do
  end subroutine fill_array
end module kernel

program main
  use cudafor
  use kernel

  ! Unified memory
  integer, managed, dimension(:), allocatable :: a, b, c
  integer :: idx, threads_per_block = 0, no_of_blocks = 0
  integer :: n = 4

  ! 1/2 Allocate unified memory
  allocate(a(n))
  allocate(b(n))
  allocate(c(n))

  ! 3 Populate/initialize the data
  call fill_array(n, a)
  call fill_array(n, b)

  ! 5 Call the GPU function
  threads_per_block = 2
  no_of_blocks = n / threads_per_block
  call device_add<<<no_of_blocks, threads_per_block>>>(n, a, b, c)

  ! 6 Synchronize the device and host
  istat = cudaDeviceSynchronize()

  ! 8 Consume the crunched data on Host
  do idx = 1, n
     write(*, '(1X, I0, A, I0, A, I0)') a(idx), " + ", b(idx), "  = ", c(idx)
  end do

  ! 9/10 Free unified
  deallocate(a)
  deallocate(b)
  deallocate(c)

end program main
