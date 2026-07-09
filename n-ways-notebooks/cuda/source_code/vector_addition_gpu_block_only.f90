module kernel
contains

  subroutine host_add(n, a, b, c)
    integer :: n
    integer :: a(n), b(n), c(n)
    integer :: idx

    do idx = 1, n
       c(idx) = a(idx) + b(idx)
    end do
  end subroutine host_add

  attributes(global) subroutine device_add(n, a, b, c)
    integer, value  :: n
    integer, device :: a(n), b(n), c(n)

    c(blockidx%x) = a(blockidx%x) + b(blockidx%x)
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

  type(dim3) :: blockSize, gridSize
  integer :: idx, threads_per_block = 0, no_of_blocks = 0
  integer :: n = 4

  ! Host copies of a, b, c
  integer, dimension(:), allocatable :: h_a, h_b, h_c

  ! Host copies of a, b, c
  integer, device, dimension(:), allocatable :: d_a, d_b, d_c

  ! 1 Allocate memory on the CPU
  allocate(h_a(n))
  allocate(h_b(n))
  allocate(h_c(n))

  ! 2 Allocate memory on the GPU
  allocate(d_a(n))
  allocate(d_b(n))
  allocate(d_c(n))

  ! 3 Populate/initialize the CPU
  call fill_array(n, h_a)
  call fill_array(n, h_b)

  ! 4 Transfer the data from the host to the device with cudaMemcpy()
  istat = cudaMemcpy(d_a, h_a, n)
  istat = cudaMemcpy(d_b, h_b, n)

  ! 5 Call the GPU function
  call device_add<<<n, 1>>>(n, d_a, d_b, d_c)

  ! 6 Synchronize the device and host
  istat = cudaDeviceSynchronize()

  ! 7 Transfer data from the device to the host with cudaMemcpy()
  istat = cudaMemcpy(h_c, d_c, n)

  ! 8 Consume the crunched data on Host
  do idx = 1, n
     write(*, '(1X, I0, A, I0, A, I0)') h_a(idx), " + ", h_b(idx), "  = ", h_c(idx)
  end do

  ! 9 Free memory on Host
  deallocate(h_a)
  deallocate(h_b)
  deallocate(h_c)

  ! 10 Free memory on Device
  deallocate(d_a)
  deallocate(d_b)
  deallocate(d_c)

end program main
