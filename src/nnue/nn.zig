const std = @import("std");
const assert = std.debug.assert;

pub const ActivationFunction = enum {
    ReLU,
    Identity,
};

pub fn Layer(comptime InputType_: type, comptime inputs_size_: usize, comptime OutputType_: type, comptime outputs_size_: usize, comptime activation_function: ActivationFunction) type {
    return struct {
        const SelfType = @This();

        const InputType: type = InputType_;
        const inputs_size: usize = inputs_size_;

        const OutputType: type = OutputType_;
        const outputs_size: usize = outputs_size_;

        weights: [outputs_size_][inputs_size_]SelfType.InputType = undefined,
        biases: [inputs_size_]SelfType.InputType = undefined,

        pub fn feedForward(self: *const SelfType, inputs: [*]SelfType.InputType, outputs: [*]SelfType.OutputType) void {
            comptime var neuron_index: usize = 0;
            inline while (neuron_index < outputs_size_) : (neuron_index += 1) {
                var input_index: usize = 0;
                var neuron_result: SelfType.OutputType = 0;
                while (input_index < inputs_size_) : (input_index += 1) {
                    var input_result: SelfType.InputType = self.weights[neuron_index][input_index] * inputs[input_index] + self.biases[input_index];
                    input_result = switch (activation_function) {
                        .ReLU => std.math.min(@as(SelfType.InputType, std.math.maxInt(SelfType.OutputType)), std.math.max(0, input_result)),
                        .Identity => std.math.max(@as(SelfType.InputType, std.math.minInt(SelfType.OutputType)), std.math.min(@as(SelfType.InputType, std.math.maxInt(SelfType.OutputType)), input_result)),
                    };
                    neuron_result += @intCast(SelfType.OutputType, input_result);
                }
                outputs[neuron_index] = neuron_result;
            }
        }
    };
}

pub fn Network(comptime layer_list: anytype) type {
    return struct {
        const SelfType = @This();

        const InputType = @TypeOf(layer_list[0]).InputType;
        const inputs_size = @TypeOf(layer_list[0]).inputs_size;

        const OutputType = @TypeOf(layer_list[layer_list.len - 1]).OutputType;
        const outputs_size = @TypeOf(layer_list[layer_list.len - 1]).outputs_size;

        layers: @TypeOf(layer_list) = layer_list,

        pub fn feedForward(self: *const SelfType, inputs: [*]SelfType.InputType, outputs: [*]SelfType.OutputType) void {
            comptime assert(self.layers.len > 0);

            var layer_inputs = inputs;
            comptime var layer_index: usize = 0;
            inline while (layer_index < self.layers.len - 1) : (layer_index += 1) {
                const layer = self.layers[layer_index];
                var layer_outputs: [@TypeOf(layer).outputs_size]InputType = undefined;
                layer.feedForward(layer_inputs, &layer_outputs);
                layer_inputs = &layer_outputs;
            }
            self.layers[layer_index].feedForward(layer_inputs, outputs);
        }
    };
}

pub fn ParallelNetworkGroup(comptime network_list: anytype) type {
    return struct {
        const SelfType = @This();

        const InputType = @TypeOf(network_list[0]).InputType;
        const inputs_size = comptime calculateInputsSize();

        const OutputType = @TypeOf(network_list[0]).OutputType;
        const outputs_size = comptime calculateOutputsSize();

        networks: @TypeOf(network_list) = network_list,

        pub fn feedForward(self: *const SelfType, inputs: [*]SelfType.InputType, outputs: [*]SelfType.OutputType) void {
            comptime assert(self.networks.len > 0);

            comptime var inputs_index = 0;
            comptime var outputs_index = 0;
            comptime var network_index: usize = 0;
            inline while (network_index < network_list.len) : (network_index += 1) {
                const network = &self.networks[network_index];

                comptime assert(@TypeOf(network.*).InputType == SelfType.InputType);
                comptime assert(@TypeOf(network.*).OutputType == SelfType.OutputType);

                network.feedForward(inputs + inputs_index, outputs + outputs_index);

                inputs_index += @TypeOf(network.layers[0]).inputs_size;
                outputs_index += @TypeOf(network.layers[network.layers.len - 1]).outputs_size;
            }
        }

        fn calculateInputsSize() usize {
            var inputs_size_counter: usize = 0;
            comptime var network_index = 0;
            inline while (network_index < network_list.len) : (network_index += 1) {
                inputs_size_counter += @TypeOf(network_list[network_index]).inputs_size;
            }
            return inputs_size_counter;
        }

        fn calculateOutputsSize() usize {
            var outputs_size_counter: usize = 0;
            comptime var network_index: usize = 0;
            inline while (network_index < network_list.len) : (network_index += 1) {
                outputs_size_counter += @TypeOf(network_list[network_index]).outputs_size;
            }
            return outputs_size_counter;
        }
    };
}

pub fn SerialNetworkGroup(comptime network_list: anytype) type {
    return struct {
        const SelfType = @This();

        const FirstNetworkType = @TypeOf(network_list[0]);
        const InputType = FirstNetworkType.InputType;
        const inputs_size = FirstNetworkType.inputs_size;

        const LastNetworkType = @TypeOf(network_list[network_list.len - 1]);
        const OutputType = LastNetworkType.OutputType;
        const outputs_size = LastNetworkType.outputs_size;

        networks: @TypeOf(network_list) = network_list,

        pub fn feedForward(self: *const SelfType, inputs: [*]SelfType.InputType, outputs: [*]SelfType.OutputType) void {
            comptime assert(self.networks.len > 0);

            var network_inputs = inputs;
            comptime var network_index: usize = 0;
            inline while (network_index < network_list.len - 1) : (network_index += 1) {
                const network = &self.networks[network_index];
                const network_type = @TypeOf(network.*);

                var network_outputs: [network_type.outputs_size]network_type.OutputType = undefined;
                network.feedForward(network_inputs, &network_outputs);

                network_inputs = &network_outputs;
            }
            self.networks[network_index].feedForward(network_inputs, outputs);
        }
    };
}

//const possible_king_squares = 64;
//const possible_non_king_piece_color_squares = 5 * 2 * 64; // No +1 for the captured piece from the Shogi NNUE implementation
//const halfkp_size = possible_king_squares * possible_non_king_piece_color_squares;
//
//const WhiteInputLayer = Layer(i16, halfkp_size, i8, halfkp_size);
//const WhiteInputAffineLayer = Layer(i8, halfkp_size, i8, 256);
//const white_input_network = Network(.{ readWhiteInputLayer(), readWhiteInputAffineLayer() }){};
//
//const BlackInputLayer = Layer(i16, halfkp_size, i8, halfkp_size);
//const BlackAffineLayer = Layer(i8, halfkp_size, i8, 256);
//const black_input_network = Network(.{ readBlackInputLayer(), readBlackInputAffineLayer() }){};
//
//const board_input_network = ParallelNetworkGroup(.{ white_input_network, black_input_network }){};
//
//const HiddenLayer1 = Layer(i8, 2 * 256, i8, 32 * 32);
//const HiddenLayer2 = Layer(i8, 32 * 32, i8, 32);
//const OutputLayer = Layer(i8, 32, i32, 1);
//const evaluation_hidden_network = Network(.{ readHiddenLayer1(), readHiddenLayer2(), readOutputLayer() }){};
//
//pub const halfkp_2x256_32_32_network = SerialNetworkGroup(.{ board_input_network, evaluation_hidden_network });

test "Layer Identity Test" {
    const layer = Layer(i16, 2, i8, 2, .Identity){
        .weights = [2][2]i16{
            [2]i16{ -50, 4 },
            [2]i16{ 3, 4 },
        },
        .biases = [2]i16{ 10, 50 },
    };

    var inputs = [2]i16{ 2, 3 };
    var outputs: [2]i8 = undefined;
    layer.feedForward(&inputs, &outputs);

    assert(outputs[0] == -28);
    assert(outputs[1] == 78);
}

test "Layer ReLU Test" {
    const layer = Layer(i16, 2, i8, 2, .ReLU){
        .weights = [2][2]i16{
            [2]i16{ -50, 4 },
            [2]i16{ 3, 4 },
        },
        .biases = [2]i16{ 10, 50 },
    };

    var inputs = [2]i16{ 2, 3 };
    var outputs: [2]i8 = undefined;
    layer.feedForward(&inputs, &outputs);

    assert(outputs[0] == 62);
    assert(outputs[1] == 78);
}

test "Network Test" {
    const layer1 = Layer(i16, 2, i16, 2, .Identity){
        .weights = [2][2]i16{
            [2]i16{ 2, 4 },
            [2]i16{ 3, 4 },
        },
        .biases = [2]i16{ 10, 50 },
    };
    const layer2 = Layer(i16, 2, i16, 1, .Identity){
        .weights = [1][2]i16{
            [2]i16{ 3, 5 },
        },
        .biases = [2]i16{ 1, 2 },
    };
    const network = Network(.{ layer1, layer2 }){};

    var inputs = [2]i16{ 2, 3 };
    var outputs: [1]i16 = undefined;
    network.feedForward(&inputs, &outputs);

    assert(outputs[0] == 621);
}

test "Parallel Network Test" {
    const layer1 = Layer(i16, 2, i16, 2, .Identity){
        .weights = [2][2]i16{
            [2]i16{ 2, 4 },
            [2]i16{ 3, 4 },
        },
        .biases = [2]i16{ 10, 50 },
    };
    const layer2n1 = Layer(i16, 2, i16, 1, .Identity){
        .weights = [1][2]i16{
            [2]i16{ 3, 5 },
        },
        .biases = [2]i16{ 1, 2 },
    };
    const layer2n2 = Layer(i16, 2, i16, 1, .Identity){
        .weights = [1][2]i16{
            [2]i16{ 3, 6 },
        },
        .biases = [2]i16{ 1, 2 },
    };
    const network1 = Network(.{ layer1, layer2n1 }){};
    const network2 = Network(.{ layer1, layer2n2 }){};
    const parallel_networks = ParallelNetworkGroup(.{ network1, network2 }){};

    var inputs = [4]i16{ 2, 3, 2, 3 };
    var outputs: [2]i16 = undefined;
    parallel_networks.feedForward(&inputs, &outputs);

    assert(outputs[0] == 621);
    assert(outputs[1] == 699);
}

test "Serial Network Test" {
    const layer1 = Layer(i16, 2, i16, 2, .Identity){
        .weights = [2][2]i16{
            [2]i16{ 2, 4 },
            [2]i16{ 3, 4 },
        },
        .biases = [2]i16{ 10, 50 },
    };
    const layer2 = Layer(i16, 2, i16, 1, .Identity){
        .weights = [1][2]i16{
            [2]i16{ 3, 5 },
        },
        .biases = [2]i16{ 1, 2 },
    };
    const network1 = Network(.{layer1}){};
    const network2 = Network(.{layer2}){};
    const serial_networks = SerialNetworkGroup(.{ network1, network2 }){};

    var inputs = [2]i16{ 2, 3 };
    var outputs: [1]i16 = undefined;
    serial_networks.feedForward(&inputs, &outputs);

    assert(outputs[0] == 621);
}

test "Composed Parallel and Serial Networks Test" {
    const layer1g1 = Layer(i16, 2, i16, 2, .Identity){
        .weights = [2][2]i16{
            [2]i16{ 2, 4 },
            [2]i16{ 3, 4 },
        },
        .biases = [2]i16{ 10, 50 },
    };
    const layer2n1g1 = Layer(i16, 2, i16, 1, .Identity){
        .weights = [1][2]i16{
            [2]i16{ 3, 5 },
        },
        .biases = [2]i16{ 1, 2 },
    };
    const layer2n2g1 = Layer(i16, 2, i16, 1, .Identity){
        .weights = [1][2]i16{
            [2]i16{ 3, 6 },
        },
        .biases = [2]i16{ 1, 2 },
    };
    const network1g1 = Network(.{ layer1g1, layer2n1g1 }){};
    const network2g1 = Network(.{ layer1g1, layer2n2g1 }){};
    const parallel_networks = ParallelNetworkGroup(.{ network1g1, network2g1 }){};

    const layer1g2 = Layer(i16, 2, i16, 1, .Identity){
        .weights = [1][2]i16{
            [2]i16{ -1, 1 },
        },
        .biases = [2]i16{ 1, 6 },
    };
    const networkg2 = Network(.{layer1g2}){};
    const composed_network = SerialNetworkGroup(.{ parallel_networks, networkg2 }){};

    var inputs = [4]i16{ 2, 3, 2, 3 };
    var outputs: [1]i16 = undefined;
    composed_network.feedForward(&inputs, &outputs);

    assert(outputs[0] == 85);
}
