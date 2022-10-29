# Copyright 2018 - 2022, Mathijs Saey, Vrije Universiteit Brussel

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Skitter.DSL.Operation, only: :macros

defoperation Skitter.BIO.TCPSource, out: _, strategy: Skitter.BIS.PassiveSource do
  @operationdoc """
  TCP source operation.

  This operation is a source which listens to data on a tcp socket. This operation should be
  embedded in the workflow with a keyword list as its argument. This list should contain `address`
  and `port` keys, which specify the address and port to connect to, respectively.

  A data element is emitted for each line sent to the tcp socket.
  """
  defcb subscribe(config) do
    opts = [:binary, reuseaddr: true, packet: :line]
    addr = to_charlist(config[:address])
    port = config[:port]
    :gen_tcp.connect(addr, port, opts)
  end

  defcb process({:tcp, _, msg}), do: msg ~> _
  defcb process({:tcp_closed, _}), do: IO.puts("TCP connection closed")
end
